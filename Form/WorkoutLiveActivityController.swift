import ActivityKit
import Foundation

@MainActor
enum WorkoutLiveActivityController {
    private static var currentActivity: Activity<WorkoutActivityAttributes>? {
        Activity<WorkoutActivityAttributes>.activities.first
    }

    static func begin(session: WorkoutSessionState) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = activityContent(session: session)

        if let currentActivity {
            if currentActivity.attributes.sessionID == session.sessionID {
                await currentActivity.update(content)
                return
            }
            await currentActivity.end(content, dismissalPolicy: .immediate)
        }

        do {
            _ = try Activity.request(
                attributes: WorkoutActivityAttributes(
                    sessionID: session.sessionID,
                    routineName: session.routine.name,
                    startedAt: session.startedAt
                ),
                content: content,
                pushType: nil
            )
        } catch {
            // Live Activity availability must never interrupt workout logging.
        }
    }

    static func update(session: WorkoutSessionState) async {
        guard let currentActivity else {
            await begin(session: session)
            return
        }
        guard currentActivity.attributes.sessionID == session.sessionID else {
            await begin(session: session)
            return
        }
        await currentActivity.update(activityContent(session: session))
    }

    static func pause(snapshot: ActiveWorkoutSnapshot) async {
        guard let currentActivity else { return }
        let routine = WorkoutCatalog.routine(id: snapshot.routineID)
        let completed = snapshot.exercises.filter { exercise in
            guard let template = WorkoutCatalog.exercise(id: exercise.exerciseID) else {
                return exercise.sets.contains(where: \.completed)
            }
            return exercise.sets.filter {
                $0.completed && ($0.kind ?? .working) == .working
            }.count >= template.sets
        }.count
        let currentExercise = snapshot.expandedExerciseID
            .flatMap(WorkoutCatalog.exercise(id:))?.name
            ?? routine?.exercises.first(where: { exercise in
                guard let saved = snapshot.exercises.first(where: {
                    $0.exerciseID == exercise.id
                }) else { return true }
                return saved.sets.filter {
                    $0.completed && ($0.kind ?? .working) == .working
                }.count < exercise.sets
            })?.name
            ?? routine?.name
            ?? currentActivity.attributes.routineName

        let state = WorkoutActivityAttributes.ContentState(
            completedMovements: completed,
            totalMovements: routine?.exercises.count ?? snapshot.exercises.count,
            currentExercise: currentExercise,
            restEnd: activeRestEnd(snapshot.restEnd),
            sessionTimerStartedAt: nil,
            pausedDuration: max(0, snapshot.activeDuration ?? 0)
        )
        await currentActivity.update(
            ActivityContent(state: state, staleDate: activeRestEnd(snapshot.restEnd))
        )
    }

    /// Finishes a completed/discarded session. If a resumable snapshot remains,
    /// the Live Activity is paused instead of dismissed.
    static func end() async {
        if let snapshot = ActiveWorkoutStore.load() {
            await pause(snapshot: snapshot)
            return
        }
        await forceEnd()
    }

    static func forceEnd() async {
        let finalState = WorkoutActivityAttributes.ContentState(
            completedMovements: 0,
            totalMovements: 0,
            currentExercise: "",
            restEnd: nil,
            sessionTimerStartedAt: nil,
            pausedDuration: 0
        )
        for activity in Activity<WorkoutActivityAttributes>.activities {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
    }

    private static func activityContent(
        session: WorkoutSessionState
    ) -> ActivityContent<WorkoutActivityAttributes.ContentState> {
        let restEnd = activeRestEnd(session.restEnd)
        let state = WorkoutActivityAttributes.ContentState(
            completedMovements: session.completedMovementCount,
            totalMovements: session.drafts.count,
            currentExercise: session.currentExerciseName,
            restEnd: restEnd,
            sessionTimerStartedAt: session.sessionTimerStartedAt,
            pausedDuration: max(0, session.elapsedActiveDuration)
        )
        return ActivityContent(state: state, staleDate: restEnd)
    }

    private static func activeRestEnd(_ date: Date?) -> Date? {
        guard let date, date > Date() else { return nil }
        return date
    }
}
