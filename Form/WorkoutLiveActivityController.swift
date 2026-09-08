import ActivityKit
import Foundation

@MainActor
enum WorkoutLiveActivityController {
    static var isSessionPresented = false
    private static var restRefreshTask: Task<Void, Never>?
    private static var scheduledRestEnd: Date?
    private static var pendingUpdate: Task<Void, Never>?

    // Serialize ActivityKit mutations so an update cannot race a start or finish.
    private static func enqueue(_ operation: @escaping @MainActor () async -> Void) async {
        let previous = pendingUpdate
        let task = Task { @MainActor in
            await previous?.value
            await operation()
        }
        pendingUpdate = task
        await task.value
    }

    static func begin(session: WorkoutSessionState) async {
        let attributes = WorkoutActivityAttributes(
            sessionID: session.sessionID, routineName: session.routine.name, startedAt: session.startedAt
        )
        let content = activityContent(session: session)
        await enqueue {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            for activity in Activity<WorkoutActivityAttributes>.activities {
                if activity.attributes.sessionID == attributes.sessionID {
                    await activity.update(content)
                    scheduleRestRefresh(activity: activity, content: content)
                    return
                }
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            if let activity = try? Activity.request(attributes: attributes, content: content, pushType: nil) {
                scheduleRestRefresh(activity: activity, content: content)
            }
        }
    }

    static func update(session: WorkoutSessionState) async { await begin(session: session) }

    static func pause(snapshot: ActiveWorkoutSnapshot) async {
        guard let routine = snapshot.resolvedRoutine else { return }
        let state = WorkoutSessionState(routine: routine, snapshot: snapshot)
        state.pause()
        let content = activityContent(session: state)
        await enqueue {
            for activity in Activity<WorkoutActivityAttributes>.activities
            where activity.attributes.sessionID == snapshot.sessionID {
                await activity.update(content)
                scheduleRestRefresh(activity: activity, content: content)
            }
        }
    }

    static func end() async {
        if let snapshot = ActiveWorkoutStore.load() { await pause(snapshot: snapshot) }
        else { await forceEnd() }
    }

    static func forceEnd() async {
        await enqueue {
            restRefreshTask?.cancel()
            scheduledRestEnd = nil
            for activity in Activity<WorkoutActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private static func activityContent(session: WorkoutSessionState) -> ActivityContent<LiveWorkoutState> {
        let exercise = session.drafts.first { $0.id == session.expandedExerciseID }
            ?? session.drafts.first { !session.isExerciseComplete($0) }
        let state = LiveWorkoutState(
            completedMovements: session.completedMovementCount,
            totalMovements: session.drafts.count,
            currentExercise: session.currentExerciseName,
            restEnd: session.restEnd,
            sessionTimerStartedAt: session.sessionTimerStartedAt,
            pausedDuration: max(0, session.elapsedActiveDuration),
            exerciseArtwork: artwork(for: exercise?.id),
            walkTimerStartedAt: session.timedWalk?.timerStartedAt,
            isWalk: session.timedWalk != nil,
            restFinished: session.restEnd.map { $0 <= Date() }
        )
        // Supply a deadline for WidgetKit's stale-state presentation. The
        // countdown stops at zero; refresh timing while suspended is system-controlled.
        let deadline = state.sessionTimerStartedAt != nil && state.isWalk != true ? state.restEnd : nil
        return ActivityContent(state: state, staleDate: deadline)
    }

    private static func scheduleRestRefresh(activity: Activity<WorkoutActivityAttributes>, content: ActivityContent<LiveWorkoutState>) {
        let end = content.state.phase() == .resting ? content.state.restEnd : nil
        guard end != scheduledRestEnd else { return }
        restRefreshTask?.cancel()
        scheduledRestEnd = end
        guard let end else { return }
        restRefreshTask = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(max(0, end.timeIntervalSinceNow))) }
            catch { return }
            guard !Task.isCancelled else { return }
            await enqueue {
                guard scheduledRestEnd == end,
                      activity.content.state.restEnd == end,
                      activity.content.state.sessionTimerStartedAt != nil else { return }
                var ready = activity.content.state
                ready.restFinished = true
                await activity.update(ActivityContent(state: ready, staleDate: nil))
                scheduledRestEnd = nil
            }
        }
    }

    private static func artwork(for id: String?) -> String {
        switch id {
        case "barbell-back-squat", "bodyweight-squat": "squat"
        case "barbell-bench-press": "bench-press"
        case "seated-row": "seated-row"
        case "leg-curl": "leg-curl"
        case "barbell-romanian-deadlift", "romanian-deadlift": "rdl"
        case "barbell-incline-press", "incline-press": "incline-press"
        case "lat-pulldown", "underhand-lat-pulldown": "pulldown"
        case "reverse-lunge", "split-squat": "reverse-lunge"
        default: "arrive"
        }
    }
}
