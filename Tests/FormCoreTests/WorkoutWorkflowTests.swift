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
