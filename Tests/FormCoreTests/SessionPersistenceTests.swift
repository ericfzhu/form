import XCTest
import SwiftData
@testable import FormCore

final class SessionPersistenceTests: XCTestCase {
    @MainActor
    func testFinishedSessionIsNotResumedEvenIfSnapshotSurvives() throws {
        let container = try ModelContainer(
            for: WorkoutRecord.self, ExerciseRecord.self, SetRecord.self, CardioRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0])
        session.drafts[0].sets[0].completed = true
        session.pause()
        let record = try WorkoutRepository.saveCompletedSession(session, in: container.mainContext)
        let savedExercise = try XCTUnwrap(record.exercises.first {
            $0.exerciseID == session.drafts[0].id
        })
        XCTAssertEqual(savedExercise.sets.count, 1)

        try withStore { store, directory, defaults in
            // Simulate termination after history saves but before snapshot cleanup.
            try store.save(session.snapshot)
            XCTAssertNil(store.load(completedWorkouts: [record]))
            XCTAssertNil(ActiveSessionStore(directory: directory, defaults: defaults).load())
        }
    }

    @MainActor
    func testUnfinishedSessionRemainsResumableRegardlessOfAge() throws {
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0], now: startedAt)
        session.drafts[0].sets[0].completed = true
        session.pause(at: startedAt.addingTimeInterval(60))
        let differentSession = WorkoutRecord(
            date: startedAt.addingTimeInterval(-3600),
            routineID: session.routine.id, routineName: session.routine.name, duration: 60
        )
        try withStore { store, directory, defaults in
            try store.save(session.snapshot)
            let restored = ActiveSessionStore(directory: directory, defaults: defaults)
            XCTAssertEqual(restored.load(completedWorkouts: [differentSession]), session.snapshot)
        }
    }

    @MainActor
    func testDiscardClearsBothCurrentAndLegacySnapshots() throws {
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0])
        session.pause()
        try withStore { store, directory, defaults in
            try store.save(session.snapshot)
            defaults.set(try JSONEncoder().encode(session.snapshot), forKey: "active-workout-snapshot-v1")
            store.clear()
            XCTAssertNil(ActiveSessionStore(directory: directory, defaults: defaults).load())
            XCTAssertNil(defaults.data(forKey: "active-workout-snapshot-v1"))
        }
    }

    @MainActor
    func testCompletedLegacySnapshotIsRemovedDuringMigration() throws {
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0])
        session.pause()
        var snapshot = session.snapshot
        snapshot.sessionID = nil
        let record = WorkoutRecord(date: session.startedAt, routineID: session.routine.id,
                                   routineName: session.routine.name, duration: 60)
        try withStore { store, directory, defaults in
            defaults.set(try JSONEncoder().encode(snapshot), forKey: "active-workout-snapshot-v1")
            XCTAssertNil(store.load(completedWorkouts: [record]))
            XCTAssertNil(ActiveSessionStore(directory: directory, defaults: defaults).load())
        }
    }

    @MainActor
    func testUnreadableSnapshotIsReportedAndCannotBeOverwritten() throws {
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0])
        try withStore { store, directory, _ in
            let file = directory.appendingPathComponent("active-workout.json")
            let damaged = Data("invalid snapshot".utf8)
            try damaged.write(to: file)
            XCTAssertThrowsError(try store.loadChecked())
            XCTAssertThrowsError(try store.save(session.snapshot))
            XCTAssertEqual(try Data(contentsOf: file), damaged)
            try store.clearChecked()
            XCTAssertNil(try store.loadChecked())
        }
    }

    @MainActor
    func testNewerSnapshotIsPreservedUntilExplicitDiscard() throws {
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0])
        try withStore { store, directory, _ in
            try store.save(session.snapshot)
            let file = directory.appendingPathComponent("active-workout.json")
            var envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
            envelope["schemaVersion"] = 999
            let newer = try JSONSerialization.data(withJSONObject: envelope)
            try newer.write(to: file)
            XCTAssertThrowsError(try store.loadChecked()) { error in
                XCTAssertEqual(error as? ActiveSessionStore.RecoveryError, .newerVersion)
            }
            XCTAssertThrowsError(try store.save(session.snapshot))
            XCTAssertEqual(try Data(contentsOf: file), newer)
        }
    }

    func testMissingSnapshotIsNotARecoveryError() throws {
        try withStore { store, _, _ in
            XCTAssertNil(try store.loadChecked())
            XCTAssertNoThrow(try store.clearChecked())
        }
    }

    @MainActor
    func testActualWriteAndDeleteFailuresPreserveSnapshotUntilRetry() throws {
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0])
        session.pause()
        try withStore { store, directory, _ in
            try store.save(session.snapshot)
            let original = try store.loadChecked()
            try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
            defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path) }
            session.drafts[0].sets[0].weight = 42
            XCTAssertThrowsError(try store.save(session.snapshot))
            XCTAssertThrowsError(try store.clearChecked())
            XCTAssertEqual(try store.loadChecked(), original)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
            try store.save(session.snapshot)
            XCTAssertEqual(try store.loadChecked(), session.snapshot)
            try store.clearChecked()
            XCTAssertNil(try store.loadChecked())
        }
    }

    @MainActor
    func testFailedLegacyMigrationPreservesSourceForRetry() throws {
        let session = WorkoutSessionState(routine: FormRoutine.sessions[0])
        try withStore { store, directory, defaults in
            let data = try JSONEncoder().encode(session.snapshot)
            defaults.set(data, forKey: "active-workout-snapshot-v1")
            try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
            defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path) }
            XCTAssertThrowsError(try store.loadChecked())
            XCTAssertEqual(defaults.data(forKey: "active-workout-snapshot-v1"), data)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
            XCTAssertNotNil(try store.loadChecked())
            XCTAssertNil(defaults.data(forKey: "active-workout-snapshot-v1"))
        }
    }

    private func withStore(_ body: (ActiveSessionStore, URL, UserDefaults) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "SessionPersistenceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suite)
        }
        try body(ActiveSessionStore(directory: directory, defaults: defaults), directory, defaults)
    }
}
