import Foundation

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

struct HealthSyncJob: Codable, Identifiable, Equatable {
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

actor HealthSyncQueueStore {
    static let shared = HealthSyncQueueStore()

    private struct Envelope: Codable {
        let schemaVersion: Int
        var jobs: [HealthSyncJob]
    }

    private let fileURL: URL
    private var cachedJobs: [HealthSyncJob]?

    init(directory: URL? = nil, fileManager: FileManager = .default) {
        let root = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        let directory = directory ?? root.appendingPathComponent("Form", isDirectory: true)
        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        fileURL = directory.appendingPathComponent("health-sync-queue.json")
    }

    func jobs() throws -> [HealthSyncJob] {
        try loadIfNeeded()
        return cachedJobs ?? []
    }

    func enqueueSave(payload: HealthWorkoutPayload, replacing previousWorkoutUUID: UUID?) throws {
        var jobs = try jobs()
        jobs.removeAll { $0.kind == .save && $0.recordIdentifier == payload.syncIdentifier }
        jobs.append(.save(payload: payload, replacing: previousWorkoutUUID))
        try persist(jobs)
    }

    func enqueueDelete(recordIdentifier: UUID, workoutUUID: UUID?) throws {
        var jobs = try jobs()
        jobs.removeAll { $0.recordIdentifier == recordIdentifier }
        jobs.append(.delete(recordIdentifier: recordIdentifier, workoutUUID: workoutUUID))
        try persist(jobs)
    }

    func remove(_ id: UUID) throws {
        var jobs = try jobs()
        jobs.removeAll { $0.id == id }
        try persist(jobs)
    }

    func update(_ job: HealthSyncJob) throws {
        var jobs = try jobs()
        // A newer edit/delete may have superseded this job while HealthKit awaited.
        guard let index = jobs.firstIndex(where: { $0.id == job.id }) else { return }
        jobs[index] = job
        try persist(jobs)
    }

    private func loadIfNeeded() throws {
        guard cachedJobs == nil else { return }
        let data: Data
        do { data = try Data(contentsOf: fileURL) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            cachedJobs = []
            return
        }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.schemaVersion == 1 else {
            throw CocoaError(.fileReadUnknown)
        }
        cachedJobs = envelope.jobs
    }

    private func persist(_ jobs: [HealthSyncJob]) throws {
        let envelope = Envelope(schemaVersion: 1, jobs: jobs)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(envelope)
        try data.write(to: fileURL, options: .atomic)
        cachedJobs = jobs
    }
}
