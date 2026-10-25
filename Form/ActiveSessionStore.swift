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

    enum RecoveryError: LocalizedError {
        case unreadable, newerVersion
        var errorDescription: String? {
            switch self {
            case .unreadable: return "The saved session couldn’t be read. Retry, or discard it to start again."
            case .newerVersion: return "This session was saved by a newer version of Form. Update the app to resume it."
            }
        }
    }

    func load(completedWorkouts: [WorkoutRecord] = []) -> ActiveWorkoutSnapshot? {
        try? loadChecked(completedWorkouts: completedWorkouts)
    }

    func loadChecked(completedWorkouts: [WorkoutRecord] = []) throws -> ActiveWorkoutSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return try loadUnlocked(completedWorkouts: completedWorkouts)
    }

    private func loadUnlocked(completedWorkouts: [WorkoutRecord] = []) throws -> ActiveWorkoutSnapshot? {
        let data: Data?
        do { data = try Data(contentsOf: fileURL) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { data = nil }
        catch { throw RecoveryError.unreadable }

        if let data {
            guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else {
                throw RecoveryError.unreadable
            }
            guard envelope.schemaVersion <= schemaVersion else { throw RecoveryError.newerVersion }
            return try resumable(envelope.snapshot, completedWorkouts: completedWorkouts)
        }
        guard let legacyData = defaults.data(forKey: legacyDefaultsKey) else { return nil }
        guard let snapshot = try? JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: legacyData) else {
            throw RecoveryError.unreadable
        }
        try saveUnlocked(snapshot)
        defaults.removeObject(forKey: legacyDefaultsKey)
        return try resumable(snapshot, completedWorkouts: completedWorkouts)
    }

    // Older records have no shared session identifier, but retain the exact
    // routine and start date from the snapshot that created them.
    private func resumable(
        _ snapshot: ActiveWorkoutSnapshot,
        completedWorkouts: [WorkoutRecord]
    ) throws -> ActiveWorkoutSnapshot? {
        guard !completedWorkouts.contains(where: {
            $0.routineID == snapshot.routineID && $0.date == snapshot.startedAt
        }) else {
            try clearUnlocked()
            return nil
        }
        return snapshot
    }

    func save(_ snapshot: ActiveWorkoutSnapshot) throws {
        lock.lock()
        defer { lock.unlock() }
        _ = try loadUnlocked() // Never overwrite an unreadable or newer session.
        try saveUnlocked(snapshot)
    }

    func clear() { try? clearChecked() }

    func clearChecked() throws {
        lock.lock()
        defer { lock.unlock() }
        try clearUnlocked()
    }

    private func clearUnlocked() throws {
        do { try FileManager.default.removeItem(at: fileURL) }
        catch let error as CocoaError where error.code == .fileNoSuchFile { }
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

    static func loadChecked(completedWorkouts: [WorkoutRecord] = []) throws -> ActiveWorkoutSnapshot? {
        try ActiveSessionStore.shared.loadChecked(completedWorkouts: completedWorkouts)
    }

    static func clearChecked() throws { try ActiveSessionStore.shared.clearChecked() }

    static func save(_ snapshot: ActiveWorkoutSnapshot) throws {
        try ActiveSessionStore.shared.save(snapshot)
    }

    static func clear() {
        ActiveSessionStore.shared.clear()
    }
}
