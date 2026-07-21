import ActivityKit
import Foundation

struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var completedMovements: Int
        var totalMovements: Int
        var currentExercise: String
        var restEnd: Date?
    }

    var routineName: String
    var startedAt: Date
}
