import Combine
import Foundation
import SwiftData

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
        do { queuedJobCount = try await queue.jobs().count }
        catch { lastError = error.localizedDescription }
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

        let jobs: [HealthSyncJob]
        do { jobs = try await queue.jobs() }
        catch { lastError = error.localizedDescription; return }
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
        guard health.canWriteWorkouts, !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }
        let jobs: [HealthSyncJob]
        do { jobs = try await queue.jobs().filter { $0.kind == .delete } }
        catch { lastError = error.localizedDescription; return }
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
