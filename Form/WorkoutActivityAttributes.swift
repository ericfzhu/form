import ActivityKit
import Foundation

struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var completedMovements: Int
        var totalMovements: Int
        var currentExercise: String
        var restEnd: Date?
        var sessionTimerStartedAt: Date?
        var pausedDuration: TimeInterval
    }

    var sessionID: UUID
    var routineName: String
    var startedAt: Date
}
