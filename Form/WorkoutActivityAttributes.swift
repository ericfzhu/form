import ActivityKit
import Foundation

struct WorkoutActivityAttributes: ActivityAttributes {
    typealias ContentState = LiveWorkoutState

    var sessionID: UUID
    var routineName: String
    var startedAt: Date
}
