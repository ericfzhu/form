import XCTest
import SwiftData
@testable import FormCore

final class BackupRecoveryTests: XCTestCase {
    @MainActor
    private func context() throws -> ModelContext {
        let container = try ModelContainer(for: WorkoutRecord.self, ExerciseRecord.self, SetRecord.self, CardioRecord.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    @MainActor
    private func backupData() throws -> Data {
        let record = WorkoutRecord(date: Date(timeIntervalSince1970: 1_800_000_000), routineName: "Audit", duration: 120)
        record.exercises = [ExerciseRecord(exerciseID: "squat", name: "Squat", assetName: "squat", order: 0,
            sets: [SetRecord(order: 0, weight: 20, repetitions: 8, kind: .working)])]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // Include an in-file duplicate as well as testing repeated imports.
        return try encoder.encode(WorkoutBackup(workouts: [record, record]).payload)
    }

    @MainActor
    func testDuplicateImportIsIdempotentAndRoundTripsSets() throws {
        let context = try context()
        let data = try backupData()
        XCTAssertEqual(try WorkoutBackup.restore(data: data, into: context), 1)
        XCTAssertEqual(try WorkoutBackup.restore(data: data, into: context), 0)
        let record = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutRecord>()).first)
        XCTAssertEqual(record.exercises.first?.sets.first?.weight, 20)
        XCTAssertEqual(record.exercises.first?.sets.first?.repetitions, 8)
        XCTAssertEqual(record.healthSyncStatus, .notRequested)
    }

    @MainActor
    func testFailedImportRollsBackAndRetryImportsOnce() throws {
        let context = try context()
        let data = try backupData()
        for _ in 0..<2 {
            XCTAssertThrowsError(try WorkoutBackup.restore(data: data, into: context) { _ in
                throw CocoaError(.fileWriteOutOfSpace)
            })
            XCTAssertTrue(try context.fetch(FetchDescriptor<WorkoutRecord>()).isEmpty)
        }
        XCTAssertEqual(try WorkoutBackup.restore(data: data, into: context), 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SetRecord>()).count, 1)
    }

    @MainActor
    func testMalformedUnsupportedAndNegativeImportsDoNotMutateHistory() throws {
        let context = try context()
        let data = try backupData()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertThrowsError(try WorkoutBackup.restore(data: Data("broken".utf8), into: context))
        object["version"] = 999
        XCTAssertThrowsError(try WorkoutBackup.restore(data: JSONSerialization.data(withJSONObject: object), into: context))
        object["version"] = 1
        var workouts = try XCTUnwrap(object["workouts"] as? [[String: Any]])
        workouts[0]["duration"] = -1
        object["workouts"] = workouts
        XCTAssertThrowsError(try WorkoutBackup.restore(data: JSONSerialization.data(withJSONObject: object), into: context))
        XCTAssertTrue(try context.fetch(FetchDescriptor<WorkoutRecord>()).isEmpty)
    }

    @MainActor
    func testRepeatedFailedEditsPreserveOriginalAndRetryDoesNotDuplicateSets() throws {
        let context = try context()
        _ = try WorkoutBackup.restore(data: backupData(), into: context)
        let record = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutRecord>()).first)
        let exercise = try XCTUnwrap(record.exercises.first)
        let drafts = [EditableExerciseDraft(record: exercise, template: FormRoutine.sessions[0].exercises[0],
                                            sets: [EditableSetDraft(weight: 35, repetitions: 10)])]
        for _ in 0..<2 {
            XCTAssertThrowsError(try WorkoutRepository.update(record, title: "Edited", date: record.date,
                durationMinutes: 3, exercises: drafts, cardioEntries: [], in: context) { _ in
                    throw CocoaError(.fileWriteOutOfSpace)
                })
            XCTAssertNil(record.sessionTitle)
            XCTAssertEqual(record.exercises.first?.sets.first?.weight, 20)
            // A later autosave after cancelling the editor must also retain the original.
            try context.save()
            let unchanged = try XCTUnwrap(ModelContext(context.container).fetch(FetchDescriptor<WorkoutRecord>()).first)
            XCTAssertNil(unchanged.sessionTitle)
            XCTAssertEqual(unchanged.exercises.first?.sets.first?.weight, 20)
        }
        try WorkoutRepository.update(record, title: "Edited", date: record.date, durationMinutes: 3,
                                     exercises: drafts, cardioEntries: [], in: context)
        XCTAssertEqual(record.sessionTitle, "Edited")
        XCTAssertEqual(record.exercises.first?.sets.first?.weight, 35)
        let fresh = ModelContext(context.container)
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<SetRecord>()).count, 1, "persisted sets")
        try context.save()
        XCTAssertEqual(try ModelContext(context.container).fetch(FetchDescriptor<SetRecord>()).count, 1, "after UI context save")
        XCTAssertEqual(record.exercises.first?.sets.count, 1)
    }
    @MainActor
    func testReplacingExercisesAndCardioAfterFailedEditHasNoOrphanedRecords() throws {
        let context = try context()
        _ = try WorkoutBackup.restore(data: backupData(), into: context)
        let record = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutRecord>()).first)
        let originalExerciseID = try XCTUnwrap(record.exercises.first?.persistentModelID)
        let drafts = [EditableExerciseDraft(record: nil, template: FormRoutine.sessions[0].exercises[1],
                                            sets: [EditableSetDraft(weight: 30, repetitions: 8)])]
        let cardio = [CardioDraft(kind: .treadmillWalk, durationMinutes: 12, averageSpeed: 5, incline: 3)]
        XCTAssertThrowsError(try WorkoutRepository.update(record, title: "Replacement", date: record.date,
            durationMinutes: 20, exercises: drafts, cardioEntries: cardio, in: context) { _ in
                throw CocoaError(.fileWriteOutOfSpace)
            })
        XCTAssertEqual(record.exercises.first?.persistentModelID, originalExerciseID)
        XCTAssertTrue(record.cardioEntries.isEmpty)
        try WorkoutRepository.update(record, title: "Replacement", date: record.date, durationMinutes: 20,
                                     exercises: drafts, cardioEntries: cardio, in: context)
        try context.save()
        let fresh = ModelContext(context.container)
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<ExerciseRecord>()).count, 1)
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<SetRecord>()).count, 1)
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<CardioRecord>()).count, 1)
        XCTAssertEqual(record.exercises.first?.exerciseID, drafts[0].template.id)
        XCTAssertEqual(record.cardioEntries.first?.durationMinutes, 12)
    }

}
