import ActivityKit
import Foundation

@MainActor
enum WorkoutLiveActivityController {
    private static var currentActivity: Activity<WorkoutActivityAttributes>? {
        Activity<WorkoutActivityAttributes>.activities.first
    }

    static func begin(
        routineName: String,
        startedAt: Date,
        completedMovements: Int,
        totalMovements: Int,
        currentExercise: String,
        restEnd: Date?
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = WorkoutActivityAttributes.ContentState(
            completedMovements: completedMovements,
            totalMovements: totalMovements,
            currentExercise: currentExercise,
            restEnd: activeRestEnd(restEnd)
        )
        let content = ActivityContent(state: state, staleDate: restEnd)

        if let currentActivity {
            let isSameWorkout = currentActivity.attributes.routineName == routineName
                && abs(currentActivity.attributes.startedAt.timeIntervalSince(startedAt)) < 1
            if isSameWorkout {
                await currentActivity.update(content)
                return
            }
            await currentActivity.end(content, dismissalPolicy: .immediate)
        }

        do {
            _ = try Activity.request(
                attributes: WorkoutActivityAttributes(
                    routineName: routineName,
                    startedAt: startedAt
                ),
                content: content,
                pushType: nil
            )
        } catch {
            // A denied or unavailable Live Activity must never interrupt workout logging.
        }
    }

    static func update(
        completedMovements: Int,
        totalMovements: Int,
        currentExercise: String,
        restEnd: Date?
    ) async {
        guard let currentActivity else { return }
        let state = WorkoutActivityAttributes.ContentState(
            completedMovements: completedMovements,
            totalMovements: totalMovements,
            currentExercise: currentExercise,
            restEnd: activeRestEnd(restEnd)
        )
        await currentActivity.update(
            ActivityContent(state: state, staleDate: restEnd)
        )
    }

    static func end() async {
        let finalState = WorkoutActivityAttributes.ContentState(
            completedMovements: 0,
            totalMovements: 0,
            currentExercise: "",
            restEnd: nil
        )
        for activity in Activity<WorkoutActivityAttributes>.activities {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
    }

    private static func activeRestEnd(_ date: Date?) -> Date? {
        guard let date, date > Date() else { return nil }
        return date
    }
}
