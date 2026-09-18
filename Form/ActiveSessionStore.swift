import Foundation

/// Owns the single resumable workout snapshot and keeps its storage format out
/// of the workout UI.
final class ActiveSessionStore {
    static let shared = ActiveSessionStore()

    private struct Envelope: Codable {
        let schemaVersion: Int
        let savedAt: Date
        let snapshot: ActiveWorkoutSnapshot
    }

    private let schemaVersion = 3
    private let legacyDefaultsKey = "active-workout-snapshot-v1"
    private let fileURL: URL
    private let defaults: UserDefaults
    private let lock = NSLock()

    init(
        fileManager: FileManager = .default,
        directory: URL? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        let root = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        let directory = directory ?? root.appendingPathComponent("Form", isDirectory: true)
        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        fileURL = directory.appendingPathComponent("active-workout.json")
    }

    func load(completedWorkouts: [WorkoutRecord] = []) -> ActiveWorkoutSnapshot? {
        lock.lock()
        defer { lock.unlock() }

        if let data = try? Data(contentsOf: fileURL),
           let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.schemaVersion <= schemaVersion {
            return resumable(envelope.snapshot, completedWorkouts: completedWorkouts)
        }

        guard let legacyData = defaults.data(forKey: legacyDefaultsKey),
              let legacySnapshot = try? JSONDecoder().decode(
                  ActiveWorkoutSnapshot.self,
                  from: legacyData
              ) else {
            return nil
        }

        try? saveUnlocked(legacySnapshot)
        defaults.removeObject(forKey: legacyDefaultsKey)
        return resumable(legacySnapshot, completedWorkouts: completedWorkouts)
    }

    // Older records have no shared session identifier, but retain the exact
    // routine and start date from the snapshot that created them.
    private func resumable(
        _ snapshot: ActiveWorkoutSnapshot,
        completedWorkouts: [WorkoutRecord]
    ) -> ActiveWorkoutSnapshot? {
        guard !completedWorkouts.contains(where: {
            $0.routineID == snapshot.routineID && $0.date == snapshot.startedAt
        }) else {
            try? FileManager.default.removeItem(at: fileURL)
            defaults.removeObject(forKey: legacyDefaultsKey)
            return nil
        }
        return snapshot
    }

    func save(_ snapshot: ActiveWorkoutSnapshot) throws {
        lock.lock()
        defer { lock.unlock() }
        try saveUnlocked(snapshot)
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.removeItem(at: fileURL)
        defaults.removeObject(forKey: legacyDefaultsKey)
    }

    private func saveUnlocked(_ snapshot: ActiveWorkoutSnapshot) throws {
        let envelope = Envelope(
            schemaVersion: schemaVersion,
            savedAt: Date(),
            snapshot: snapshot
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(envelope)
        try data.write(to: fileURL, options: .atomic)
    }
}

/// Compatibility façade used by callers that previously depended directly on
/// UserDefaults.
enum ActiveWorkoutStore {
    static func load(completedWorkouts: [WorkoutRecord] = []) -> ActiveWorkoutSnapshot? {
        ActiveSessionStore.shared.load(completedWorkouts: completedWorkouts)
    }

    static func save(_ snapshot: ActiveWorkoutSnapshot) throws {
        try ActiveSessionStore.shared.save(snapshot)
    }

    static func clear() {
        ActiveSessionStore.shared.clear()
    }
}
