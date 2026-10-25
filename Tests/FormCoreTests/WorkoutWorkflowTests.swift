import XCTest
@testable import FormCore

final class WorkoutWorkflowTests: XCTestCase {
    @MainActor
    func testLoggingLastSetStaysOnThatExerciseAndAllowsAnyOrder() {
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0])
        let index = 2
        let exerciseID = session.drafts[index].id
        for set in session.drafts[index].sets.indices {
            session.drafts[index].sets[set].completed = true
        }
        let now = Date()
        session.didCompleteSet(for: exerciseID, kind: .working, restSeconds: 60, now: now)
        XCTAssertEqual(session.expandedExerciseID, exerciseID)
        XCTAssertEqual(session.currentExerciseName, session.drafts[index].template.name)
        XCTAssertEqual(session.restEnd, now.addingTimeInterval(60))
        XCTAssertFalse(session.drafts[0].sets[0].completed)
        XCTAssertEqual(session.completedMovementCount, 1)
    }

    @MainActor
    func testRestCanBeDisabledAndWarmupsUseShorterRest() {
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0])
        let exerciseID = session.drafts[0].id
        let now = Date()
        session.didCompleteSet(for: exerciseID, kind: .warmup, restSeconds: 180, now: now)
        XCTAssertEqual(session.restEnd, now.addingTimeInterval(90))
        session.didCompleteSet(for: exerciseID, kind: .working, restSeconds: 0, now: now)
        XCTAssertNil(session.restEnd)
    }

    @MainActor
    func testReorderedWorkoutResumesWithItsSetsAndOrder() throws {
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0])
        session.drafts.swapAt(0, 3)
        session.drafts[0].sets[0].completed = true
        session.drafts[0].sets[0].weight = 42
        session.pause()
        let data = try JSONEncoder().encode(session.snapshot)
        let saved = try JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: data)
        let restored = WorkoutSessionState(routine: session.routine, snapshot: saved)
        XCTAssertEqual(restored.drafts.map(\.id), session.drafts.map(\.id))
        XCTAssertTrue(restored.drafts[0].sets[0].completed)
        XCTAssertEqual(restored.drafts[0].sets[0].weight, 42)
    }

    @MainActor
    func testAddedWorkingSetCountsTowardExerciseCompletion() {
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0])
        for index in session.drafts[0].sets.indices { session.drafts[0].sets[index].completed = true }
        XCTAssertTrue(session.isExerciseComplete(session.drafts[0]))
        session.drafts[0].sets.append(SetDraft(weight: 10, repetitions: 8))
        XCTAssertFalse(session.isExerciseComplete(session.drafts[0]))
    }

    @MainActor
    func testRequestingFinishLeavesWalkRunningUntilConfirmed() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0], now: start)
        session.startTimedWalk(now: start)
        XCTAssertEqual(session.finishDisposition(at: start.addingTimeInterval(60)), .partial)
        XCTAssertEqual(session.timedWalk?.startedAt, start)
        XCTAssertTrue(session.cardioDrafts.isEmpty)
        XCTAssertEqual(session.timedWalk?.elapsed(at: start.addingTimeInterval(90)), 90)
    }

    @MainActor
    func testFailedPauseSaveResumesSessionAndWalk() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0], now: start)
        session.startTimedWalk(now: start)
        XCTAssertThrowsError(try session.pauseAndSave(at: start.addingTimeInterval(60)) { snapshot in
            XCTAssertNil(snapshot.sessionTimerStartedAt)
            throw CocoaError(.fileWriteOutOfSpace)
        })
        XCTAssertNotNil(session.sessionTimerStartedAt)
        XCTAssertEqual(session.timedWalk?.elapsed(at: start.addingTimeInterval(90)), 90)
    }

    @MainActor
    func testFailedFinishRestoresWalkAndRetryLogsItOnce() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0], now: start)
        session.startTimedWalk(now: start)
        XCTAssertThrowsError(try session.finish(at: start.addingTimeInterval(60)) { state in
            XCTAssertEqual(state.cardioDrafts.count, 1)
            XCTAssertNil(state.timedWalk)
            throw CocoaError(.fileWriteOutOfSpace)
        })
        XCTAssertNotNil(session.timedWalk)
        XCTAssertTrue(session.cardioDrafts.isEmpty)
        _ = try session.finish(at: start.addingTimeInterval(120)) { state in
            XCTAssertEqual(state.cardioDrafts.count, 1)
            XCTAssertEqual(state.cardioDrafts[0].durationMinutes, 2)
            return WorkoutRecord(date: start, routineName: state.routine.name, duration: 120)
        }
        XCTAssertNil(session.timedWalk)
        XCTAssertNil(session.sessionTimerStartedAt)
    }

    @MainActor
    func testSnapshotIsStableBetweenActionsAndTimersSurviveRelaunch() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0], now: start)
        session.startTimedWalk(now: start.addingTimeInterval(10))
        session.restEnd = start.addingTimeInterval(180)
        let first = session.snapshot
        XCTAssertEqual(first, session.snapshot)
        let decoded = try JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: JSONEncoder().encode(first))
        let restored = WorkoutSessionState(routine: session.routine, snapshot: decoded, now: start.addingTimeInterval(60))
        XCTAssertEqual(restored.sessionTimerStartedAt, start)
        XCTAssertEqual(restored.timedWalk?.elapsed(at: start.addingTimeInterval(60)), 50)
        XCTAssertEqual(restored.restEnd, first.restEnd)
        restored.pause(at: start.addingTimeInterval(90))
        XCTAssertEqual(restored.snapshot.activeDuration, 90)
        XCTAssertEqual(restored.snapshot.timedWalk?.accumulated, 80)
    }

    func testRestPreferenceRemembersOffAndIsSpecificToExercise() throws {
        let suite = "WorkoutWorkflowTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let exercises = FormRoutine.sessions[0].exercises
        XCTAssertEqual(ExerciseRestPreference.seconds(for: exercises[0], defaults: defaults), exercises[0].restSeconds)
        defaults.set(0, forKey: ExerciseRestPreference.key(for: exercises[0].id))
        XCTAssertEqual(ExerciseRestPreference.seconds(for: exercises[0], defaults: defaults), 0)
        XCTAssertEqual(ExerciseRestPreference.seconds(for: exercises[1], defaults: defaults), exercises[1].restSeconds)
    }
}
