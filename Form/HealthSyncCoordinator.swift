import Combine
import Foundation
import SwiftData

struct HealthCardioPayload: Codable, Equatable {
    let kind: CardioKind
    let durationMinutes: Double
    let distanceKilometers: Double
}

struct HealthWorkoutPayload: Codable, Equatable {
    let syncIdentifier: UUID
    let startedAt: Date
    let duration: TimeInterval
    let hasStrengthTraining: Bool
    let cardio: [HealthCardioPayload]

    init(record: WorkoutRecord) {
        syncIdentifier = record.healthSyncIdentifier
        startedAt = record.date
        duration = max(1, record.duration)
        hasStrengthTraining = record.exercises.contains { exercise in
            exercise.sets.contains { $0.kind == .working }
        }
        cardio = record.cardioEntries
            .sorted { $0.order < $1.order }
            .map {
                HealthCardioPayload(
                    kind: $0.kind,
                    durationMinutes: max(0, $0.durationMinutes),
                    distanceKilometers: max(0, $0.distanceKilometers)
                )
            }
    }

    var hasTrainingData: Bool {
        hasStrengthTraining || cardio.contains { $0.durationMinutes > 0 }
    }
}

private struct HealthSyncJob: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case save
        case delete
    }

    let id: UUID
    let kind: Kind
    let recordIdentifier: UUID
    var payload: HealthWorkoutPayload?
    var previousWorkoutUUID: UUID?
    var attempts: Int
    let createdAt: Date
    var lastAttemptAt: Date?
    var lastError: String?

    static func save(
        payload: HealthWorkoutPayload,
        replacing previousWorkoutUUID: UUID?
    ) -> HealthSyncJob {
        HealthSyncJob(
            id: UUID(),
            kind: .save,
            recordIdentifier: payload.syncIdentifier,
            payload: payload,
            previousWorkoutUUID: previousWorkoutUUID,
            attempts: 0,
            createdAt: Date(),
            lastAttemptAt: nil,
            lastError: nil
        )
    }

    static func delete(
        recordIdentifier: UUID,
        workoutUUID: UUID?
    ) -> HealthSyncJob {
        HealthSyncJob(
            id: UUID(),
            kind: .delete,
            recordIdentifier: recordIdentifier,
            payload: nil,
            previousWorkoutUUID: workoutUUID,
            attempts: 0,
            createdAt: Date(),
            lastAttemptAt: nil,
            lastError: nil
        )
    }
}

private actor HealthSyncQueueStore {
    static let shared = HealthSyncQueueStore()

    private struct Envelope: Codable {
        let schemaVersion: Int
        var jobs: [HealthSyncJob]
    }

    private let fileURL: URL
    private var cachedJobs: [HealthSyncJob]?

    init(fileManager: FileManager = .default) {
        let root = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        let directory = root.appendingPathComponent("Form", isDirectory: true)
        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        fileURL = directory.appendingPathComponent("health-sync-queue.json")
    }

    func jobs() -> [HealthSyncJob] {
        loadIfNeeded()
        return cachedJobs ?? []
    }

    func enqueueSave(
        payload: HealthWorkoutPayload,
        replacing previousWorkoutUUID: UUID?
    ) throws {
        loadIfNeeded()
        cachedJobs?.removeAll {
            $0.kind == .save && $0.recordIdentifier == payload.syncIdentifier
        }
        cachedJobs?.append(
            .save(payload: payload, replacing: previousWorkoutUUID)
        )
        try persist()
    }

    func enqueueDelete(recordIdentifier: UUID, workoutUUID: UUID?) throws {
        loadIfNeeded()
        // A delete supersedes any unsent save for the same local workout.
        cachedJobs?.removeAll { $0.recordIdentifier == recordIdentifier }
        cachedJobs?.append(
            .delete(recordIdentifier: recordIdentifier, workoutUUID: workoutUUID)
        )
        try persist()
    }

    func remove(_ id: UUID) throws {
        loadIfNeeded()
        cachedJobs?.removeAll { $0.id == id }
        try persist()
    }

    func update(_ job: HealthSyncJob) throws {
        loadIfNeeded()
        guard let index = cachedJobs?.firstIndex(where: { $0.id == job.id }) else {
            return
        }
        cachedJobs?[index] = job
        try persist()
    }

    private func loadIfNeeded() {
        guard cachedJobs == nil else { return }
        guard let data = try? Data(contentsOf: fileURL),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.schemaVersion == 1 else {
            cachedJobs = []
            return
        }
        cachedJobs = envelope.jobs
    }

    private func persist() throws {
        let envelope = Envelope(schemaVersion: 1, jobs: cachedJobs ?? [])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(envelope)
        try data.write(to: fileURL, options: .atomic)
    }
}

@MainActor
final class HealthSyncCoordinator: ObservableObject {
    static let shared = HealthSyncCoordinator()

    @Published private(set) var queuedJobCount = 0
    @Published private(set) var isProcessing = false
    @Published private(set) var lastError: String?

    private let queue = HealthSyncQueueStore.shared
    private let health = HealthKitService.shared

    private init() {}

    func refreshPendingCount() async {
        queuedJobCount = await queue.jobs().count
    }

    func enqueueSave(
        _ record: WorkoutRecord,
        replacing previousWorkoutUUID: UUID? = nil,
        in modelContext: ModelContext
    ) async {
        guard record.hasTrainingData else {
            record.healthSyncStatus = .notRequested
            record.healthSyncLastError = nil
            try? modelContext.save()
            return
        }

        record.healthSyncStatus = .pending
        record.healthSyncLastError = nil
        do {
            try modelContext.save()
            try await queue.enqueueSave(
                payload: HealthWorkoutPayload(record: record),
                replacing: previousWorkoutUUID
            )
            await refreshPendingCount()
            await processPending(in: modelContext)
        } catch {
            record.healthSyncStatus = .failed
            record.healthSyncLastAttemptAt = Date()
            record.healthSyncLastError = error.localizedDescription
            try? modelContext.save()
            lastError = error.localizedDescription
        }
    }

    func enqueueDelete(
        recordIdentifier: UUID,
        workoutUUID: UUID?
    ) async {
        do {
            try await queue.enqueueDelete(
                recordIdentifier: recordIdentifier,
                workoutUUID: workoutUUID
            )
        } catch {
            lastError = error.localizedDescription
        }
        await refreshPendingCount()
        await processDeletesWhenPossible()
    }

    func retryPending(
        in modelContext: ModelContext,
        workouts: [WorkoutRecord]
    ) async {
        for record in workouts where record.hasTrainingData
            && (record.healthSyncStatus == .pending
                || record.healthSyncStatus == .syncing
                || record.healthSyncStatus == .failed) {
            do {
                record.healthSyncStatus = .pending
                try await queue.enqueueSave(
                    payload: HealthWorkoutPayload(record: record),
                    replacing: record.healthKitWorkoutUUID
                )
            } catch {
                record.healthSyncStatus = .failed
                record.healthSyncLastError = error.localizedDescription
                lastError = error.localizedDescription
            }
        }
        try? modelContext.save()
        await refreshPendingCount()
        await processPending(in: modelContext)
    }

    func processPending(in modelContext: ModelContext) async {
        guard health.canWriteWorkouts, !isProcessing else {
            await refreshPendingCount()
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        let jobs = await queue.jobs()
        for var job in jobs {
            job.attempts += 1
            job.lastAttemptAt = Date()

            do {
                switch job.kind {
                case .save:
                    guard let payload = job.payload else {
                        try await queue.remove(job.id)
                        continue
                    }
                    guard let record = try workout(
                        with: job.recordIdentifier,
                        in: modelContext
                    ) else {
                        try await queue.remove(job.id)
                        continue
                    }

                    record.healthSyncStatus = .syncing
                    record.healthSyncLastAttemptAt = job.lastAttemptAt
                    record.healthSyncLastError = nil
                    try modelContext.save()

                    let workoutUUID = try await health.saveWorkout(
                        from: payload,
                        replacing: job.previousWorkoutUUID
                    )
                    record.healthKitWorkoutUUID = workoutUUID
                    record.healthSyncStatus = .synced
                    record.healthSyncLastAttemptAt = Date()
                    record.healthSyncLastError = nil
                    try modelContext.save()
                    try await queue.remove(job.id)

                case .delete:
                    try await health.deleteWorkout(
                        with: job.previousWorkoutUUID,
                        externalIdentifier: job.recordIdentifier
                    )
                    try await queue.remove(job.id)
                }
            } catch {
                job.lastError = error.localizedDescription
                try? await queue.update(job)
                if let record = try? workout(
                    with: job.recordIdentifier,
                    in: modelContext
                ) {
                    record.healthSyncStatus = .failed
                    record.healthSyncLastAttemptAt = job.lastAttemptAt
                    record.healthSyncLastError = error.localizedDescription
                    try? modelContext.save()
                }
                lastError = error.localizedDescription
            }
        }

        await refreshPendingCount()
    }

    private func processDeletesWhenPossible() async {
        guard health.canWriteWorkouts else { return }
        let jobs = await queue.jobs().filter { $0.kind == .delete }
        for var job in jobs {
            job.attempts += 1
            job.lastAttemptAt = Date()
            do {
                try await health.deleteWorkout(
                    with: job.previousWorkoutUUID,
                    externalIdentifier: job.recordIdentifier
                )
                try await queue.remove(job.id)
            } catch {
                job.lastError = error.localizedDescription
                try? await queue.update(job)
                lastError = error.localizedDescription
            }
        }
        await refreshPendingCount()
    }

    private func workout(
        with identifier: UUID,
        in modelContext: ModelContext
    ) throws -> WorkoutRecord? {
        let records = try modelContext.fetch(FetchDescriptor<WorkoutRecord>())
        return records.first { $0.healthSyncIdentifier == identifier }
    }
}
