import XCTest
@testable import FormCore

final class CounterweightWorkflowTests: XCTestCase {
    func testEveryPrescribedExerciseHasTechniqueContent() {
        for exercise in FormRoutine.sessions.flatMap(\.exercises) {
            XCTAssertFalse(exercise.formCues.isEmpty, "Missing technique for \(exercise.id)")
        }
    }

    @MainActor
    func testFocusedSetSurvivesLoggingSwitchingAndRelaunch() throws {
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0])
        let exercise = session.drafts[0].id
        let laterSet = session.drafts[0].sets[1].id
        session.selectSet(laterSet, for: exercise)
        session.drafts[0].sets[1].completed = true
        session.didCompleteSet(for: exercise, kind: .working, setID: laterSet)
        XCTAssertEqual(session.selectedSetID(for: exercise), laterSet, "Logging must not move the editor")
        session.expandedExerciseID = session.drafts[1].id
        let restored = WorkoutSessionState(routine: session.routine, snapshot: try JSONDecoder().decode(
            ActiveWorkoutSnapshot.self, from: JSONEncoder().encode(session.snapshot)))
        XCTAssertEqual(restored.expandedExerciseID, session.drafts[1].id)
        XCTAssertEqual(restored.selectedSetID(for: exercise), laterSet)
        XCTAssertEqual(restored.restSourceSetID, laterSet)
    }

    @MainActor
    func testSelectionRecoversAfterRemovalAndFromOldSnapshots() {
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0])
        let exercise = session.drafts[0].id
        let removed = session.drafts[0].sets[1].id
        session.selectSet(removed, for: exercise)
        session.drafts[0].sets.removeLast()
        XCTAssertEqual(session.selectedSetID(for: exercise), session.drafts[0].sets[0].id)
        session.selectSet(UUID(), for: exercise)
        XCTAssertEqual(session.selectedSetID(for: exercise), session.drafts[0].sets[0].id)
        var snapshot = session.snapshot
        snapshot.selectedSetIDs = nil
        let restored = WorkoutSessionState(routine: session.routine, snapshot: snapshot)
        XCTAssertEqual(restored.selectedSetID(for: exercise), restored.drafts[0].sets[0].id)
    }

    @MainActor
    func testExplicitCopyReplacesInvalidRawTextEvenWhenValueIsUnchanged() {
        let form = NumberEntryForm(locale: Locale(identifier: "en_AU"))
        form.configure([NumberFieldSpec(id: "load", label: "Weight", value: 35, rule: .load)], order: ["load"])
        XCTAssertNil(form.edit("-", id: "load"))
        XCTAssertFalse(form.validate())
        form.replaceValue(35, id: "load")
        XCTAssertEqual(form.text(for: "load", fallback: 0), "35")
        XCTAssertTrue(form.validate())
        XCTAssertTrue(form.editedTexts.isEmpty)
    }

    @MainActor
    func testManualRestUsesChosenDurationWithoutRecordingAnything() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0], now: now)
        session.startManualRest(seconds: 150, now: now)
        XCTAssertEqual(session.restEnd, now.addingTimeInterval(150))
        XCTAssertNil(session.restSourceSetID)
        XCTAssertFalse(session.hasRecordedWork)
    }

    @MainActor
    func testRestBelongsToItsSetAcrossRelaunchAndUndo() throws {
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0])
        let first = session.drafts[0].sets[0].id
        let second = session.drafts[1].sets[0].id
        session.drafts[0].sets[0].completed = true
        session.didCompleteSet(for: session.drafts[0].id, kind: .working, setID: first)
        session.drafts[1].sets[0].completed = true
        session.didCompleteSet(for: session.drafts[1].id, kind: .working, setID: second)
        let decoded = try JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: JSONEncoder().encode(session.snapshot))
        let restored = WorkoutSessionState(routine: session.routine, snapshot: decoded)
        XCTAssertEqual(restored.drafts[1].sets[0].id, second)
        let deadline = restored.restEnd
        restored.undoSet(first)
        XCTAssertEqual(restored.restEnd, deadline)
        XCTAssertEqual(restored.restSourceSetID, second)
        restored.undoSet(second)
        XCTAssertNil(restored.restEnd)
        XCTAssertNil(restored.restSourceSetID)
    }

    @MainActor
    func testLastWorkingSetSuppressesRestButExtraSetRestoresIt() {
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0])
        for i in session.drafts.indices {
            for j in session.drafts[i].sets.indices { session.drafts[i].sets[j].completed = true }
        }
        let id = session.drafts[0].id
        session.didCompleteSet(for: id, kind: .working, setID: session.drafts[0].sets[0].id)
        XCTAssertNil(session.restEnd)
        session.drafts[0].sets.append(SetDraft(weight: 10, repetitions: 8))
        XCTAssertTrue(session.hasRemainingWorkingSets)
        session.didCompleteSet(for: id, kind: .working, setID: session.drafts[0].sets[0].id)
        XCTAssertNotNil(session.restEnd)
        session.clearRest()
        session.startManualRest()
        XCTAssertNotNil(session.restEnd)
        XCTAssertNil(session.restSourceSetID)
    }

    @MainActor
    func testWalkAndStrengthLoggingCoexist() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0], now: start)
        let selected = session.expandedExerciseID
        session.startManualRest(now: start)
        session.startTimedWalk(now: start)
        XCTAssertEqual(session.expandedExerciseID, selected)
        XCTAssertNotNil(session.restEnd)
        session.didCompleteSet(for: session.drafts[1].id, kind: .working, now: start.addingTimeInterval(20))
        XCTAssertEqual(session.timedWalk?.elapsed(at: start.addingTimeInterval(40)), 40)
        XCTAssertTrue(session.cardioDrafts.isEmpty)
    }

    @MainActor
    func testRawInvalidEntryAndBaselineSurvivePauseAndRelaunch() throws {
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0])
        let set = session.drafts[0].sets[0]
        let id = EntryID.load(set.id)
        let form = NumberEntryForm(locale: Locale(identifier: "en_AU"))
        let spec = NumberFieldSpec(id: id, label: "Weight", value: set.weight, rule: .load)
        form.configure([spec], order: [id])
        XCTAssertNil(form.edit("-", id: id))
        session.entryTexts = form.editedTexts
        session.drafts[0].sets[0].repetitions += 2
        session.pause()
        let decoded = try JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: JSONEncoder().encode(session.snapshot))
        let restored = WorkoutSessionState(routine: session.routine, snapshot: decoded)
        let newForm = NumberEntryForm(locale: Locale(identifier: "en_AU"))
        newForm.configure([spec], order: [id])
        newForm.restoreEditedTexts(restored.entryTexts)
        XCTAssertEqual(newForm.text(for: id, fallback: 0), "-")
        XCTAssertFalse(newForm.validate())
        XCTAssertEqual(restored.drafts[0].sets[0].id, set.id)
        XCTAssertTrue(restored.drafts[0].sets[0].hasUnrecordedChanges)
    }

    @MainActor
    func testLegacySnapshotWithoutNewFieldsStillRestores() throws {
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0])
        var snapshot = session.snapshot
        snapshot.restSourceSetID = nil
        snapshot.entryTexts = nil
        snapshot.isCardioExpanded = nil
        for i in snapshot.exercises.indices {
            for j in snapshot.exercises[i].sets.indices {
                snapshot.exercises[i].sets[j].id = nil
                snapshot.exercises[i].sets[j].initialWeight = nil
                snapshot.exercises[i].sets[j].initialRepetitions = nil
            }
        }
        let restored = WorkoutSessionState(routine: session.routine, snapshot: try JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: JSONEncoder().encode(snapshot)))
        XCTAssertEqual(restored.drafts.count, 4)
        XCTAssertTrue(restored.entryTexts.isEmpty)
        XCTAssertFalse(restored.drafts[0].sets[0].hasUnrecordedChanges)
        XCTAssertEqual(Set(restored.drafts.flatMap(\.sets).map(\.id)).count, 8)
    }

    @MainActor
    func testFinishOmitsEmptyCardioButFailedSavePreservesDraft() throws {
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0])
        session.drafts[0].sets[0].completed = true
        session.cardioDrafts = [CardioDraft(kind: .treadmillWalk, durationMinutes: 0)]
        XCTAssertThrowsError(try session.finish { state in
            XCTAssertTrue(state.cardioDrafts.isEmpty)
            throw CocoaError(.fileWriteOutOfSpace)
        })
        XCTAssertEqual(session.cardioDrafts.count, 1)
        _ = try session.finish { state in
            XCTAssertTrue(state.cardioDrafts.isEmpty)
            return WorkoutRecord(date: state.startedAt, routineName: state.routine.name, duration: 60)
        }
        XCTAssertTrue(session.cardioDrafts.isEmpty)
    }
}
