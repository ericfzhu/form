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

    private let schemaVersion = 2
    private let legacyDefaultsKey = "active-workout-snapshot-v1"
    private let fileURL: URL
    private let lock = NSLock()

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
        fileURL = directory.appendingPathComponent("active-workout.json")
    }

    func load() -> ActiveWorkoutSnapshot? {
        lock.lock()
        defer { lock.unlock() }

        if let data = try? Data(contentsOf: fileURL),
           let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.schemaVersion <= schemaVersion {
            return envelope.snapshot
        }

        guard let legacyData = UserDefaults.standard.data(forKey: legacyDefaultsKey),
              let legacySnapshot = try? JSONDecoder().decode(
                  ActiveWorkoutSnapshot.self,
                  from: legacyData
              ) else {
            return nil
        }

        try? saveUnlocked(legacySnapshot)
        UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
        return legacySnapshot
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
        UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
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
    static func load() -> ActiveWorkoutSnapshot? {
        ActiveSessionStore.shared.load()
    }

    static func save(_ snapshot: ActiveWorkoutSnapshot) throws {
        try ActiveSessionStore.shared.save(snapshot)
    }

    static func clear() {
        ActiveSessionStore.shared.clear()
    }
}
