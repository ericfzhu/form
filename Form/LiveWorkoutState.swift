import Foundation

/// Shared, testable presentation data. It contains no persistence or UI dependencies.
struct LiveWorkoutState: Codable, Hashable {
    enum Phase: String { case lifting, resting, ready, walking, paused }

    var completedMovements: Int
    var totalMovements: Int
    var currentExercise: String
    var restEnd: Date?
    var sessionTimerStartedAt: Date?
    var pausedDuration: TimeInterval
    var exerciseArtwork: String? = nil
    var walkTimerStartedAt: Date? = nil
    var isWalk: Bool? = nil
    var restFinished: Bool? = nil

    func phase(at now: Date = Date(), isStale: Bool = false) -> Phase {
        guard sessionTimerStartedAt != nil else { return .paused }
        if isWalk == true { return .walking }
        if let restEnd { return restEnd <= now || isStale || restFinished == true ? .ready : .resting }
        return .lifting
    }

    var progress: String {
        "\(min(max(0, completedMovements), max(0, totalMovements))) of \(max(0, totalMovements)) exercises done"
    }

    /// Validate the session identity before routing an external Live Activity URL.
    static func sessionID(from url: URL) -> UUID? {
        guard url.scheme == "form", url.host == "session",
              url.pathComponents.count == 2 else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
}

/// A real elapsed walk, separate from the suggested duration and manual entries.
struct TimedWalk: Codable, Equatable {
    var id = UUID()
    var accumulated: TimeInterval = 0
    var startedAt: Date?

    init(now: Date = Date()) { startedAt = now }

    func elapsed(at now: Date = Date()) -> TimeInterval {
        max(0, accumulated) + (startedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    var timerStartedAt: Date? { startedAt?.addingTimeInterval(-max(0, accumulated)) }

    mutating func pause(at now: Date = Date()) {
        accumulated = elapsed(at: now)
        startedAt = nil
    }

    mutating func resume(at now: Date = Date()) {
        if startedAt == nil { startedAt = now }
    }
}
