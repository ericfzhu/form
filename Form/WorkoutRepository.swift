import Foundation
import SwiftData

struct EditableSetDraft: Identifiable, Equatable {
    let id = UUID()
    var weight: Double
    var repetitions: Int
    var kind: SetKind = .working
}

struct EditableExerciseDraft: Identifiable, Equatable {
    let id = UUID()
    let record: ExerciseRecord?
    let template: ExerciseTemplate
    var sets: [EditableSetDraft]

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.record?.persistentModelID == rhs.record?.persistentModelID
            && lhs.template == rhs.template
            && lhs.sets == rhs.sets
    }
}

@MainActor
enum WorkoutRepository {
    static func delete(
        _ workout: WorkoutRecord,
        in modelContext: ModelContext,
        save: ((ModelContext) throws -> Void)? = nil
    ) throws {
        // Materialize the full graph before SwiftData snapshots a cascade
        // deletion; unfaulted child records cannot be restored by rollback.
        _ = BackupWorkout(workout)
        modelContext.delete(workout)
        do {
            try (save ?? { try $0.save() })(modelContext)
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    static func saveCompletedSession(
        _ session: WorkoutSessionState,
        in modelContext: ModelContext
    ) throws -> WorkoutRecord {
        for draft in session.drafts {
            for set in draft.sets where set.completed {
                try validate(set.weight, rule: .load)
                try validate(Double(set.repetitions), rule: .count)
            }
        }
        try validateCardio(session.cardioDrafts)
        let record = WorkoutRecord(
            date: session.startedAt,
            routineID: session.routine.id,
            routineName: session.routine.name,
            duration: session.elapsedActiveDuration
        )

        record.exercises = session.drafts.enumerated().map { exerciseIndex, draft in
            let exercise = ExerciseRecord(
                exerciseID: draft.template.id,
                name: draft.template.name,
                assetName: draft.template.assetName,
                order: exerciseIndex
            )
            exercise.sets = draft.sets.enumerated().compactMap { setIndex, set in
                guard set.completed else { return nil }
                return SetRecord(
                    order: setIndex,
                    weight: set.weight,
                    repetitions: set.repetitions,
                    kind: set.kind
                )
            }
            return exercise
        }

        record.cardioEntries = session.cardioDrafts.enumerated().compactMap { index, draft in
            guard draft.durationMinutes > 0 else { return nil }
            return CardioRecord(
                kind: draft.kind,
                order: index,
                durationMinutes: max(0, draft.durationMinutes),
                distanceKilometers: max(0, draft.distanceKilometers),
                averageSpeed: max(0, draft.averageSpeed),
                incline: draft.kind.supportsIncline ? max(0, draft.incline) : 0
            )
        }

        record.healthSyncStatus = record.hasTrainingData ? .pending : .notRequested
        modelContext.insert(record)
        try modelContext.save()
        return record
    }

    static func update(
        _ source: WorkoutRecord, title: String, date: Date, durationMinutes: Double,
        exercises: [EditableExerciseDraft], cardioEntries: [CardioDraft],
        in sourceContext: ModelContext, save: ((ModelContext) throws -> Void)? = nil
    ) throws {
        try validate(durationMinutes, rule: .duration)
        for exercise in exercises {
            for set in exercise.sets {
                if exercise.template.recordsLoad { try validate(set.weight, rule: .load) }
                try validate(Double(set.repetitions), rule: .count)
            }
        }
        try validateCardio(cardioEntries)
        let modelContext = sourceContext
        let workout = source
        let originalTitle = workout.sessionTitle
        let originalDate = workout.date
        let originalDuration = workout.duration
        let originalStatus = workout.healthSyncStatus
        let originalError = workout.healthSyncLastError
        let originalExercises = workout.exercises
        let originalCardio = workout.cardioEntries

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        workout.sessionTitle = trimmed.isEmpty ? nil : trimmed
        workout.date = date
        workout.duration = durationMinutes * 60

        // Build replacement children without mutating the originals. A failed save
        // can then restore the exact objects still referenced by the editor drafts.
        originalExercises.forEach(modelContext.delete)

        workout.exercises = exercises.enumerated().compactMap { exerciseIndex, draft in
            if draft.record == nil && draft.sets.isEmpty { return nil }
            let record = ExerciseRecord(
                exerciseID: draft.template.id,
                name: draft.template.name,
                assetName: draft.template.assetName,
                order: exerciseIndex
            )
            record.exerciseID = draft.template.id
            record.name = draft.template.name
            record.assetName = draft.template.assetName
            record.order = exerciseIndex
            record.sets = draft.sets.enumerated().map { index, set in
                SetRecord(
                    order: index,
                    weight: draft.template.recordsLoad ? set.weight : 0,
                    repetitions: set.repetitions,
                    kind: set.kind
                )
            }
            return record
        }

        let oldCardio = workout.cardioEntries
        workout.cardioEntries = []
        oldCardio.forEach(modelContext.delete)
        workout.cardioEntries = cardioEntries.enumerated().compactMap { index, entry in
            guard entry.durationMinutes > 0 else { return nil }
            return CardioRecord(
                kind: entry.kind,
                order: index,
                durationMinutes: max(0, entry.durationMinutes),
                distanceKilometers: max(0, entry.distanceKilometers),
                averageSpeed: max(0, entry.averageSpeed),
                incline: entry.kind.supportsIncline ? max(0, entry.incline) : 0
            )
        }
        workout.healthSyncStatus = workout.hasTrainingData ? .pending : .notRequested
        workout.healthSyncLastError = nil

        do { try (save ?? { try $0.save() })(modelContext) }
        catch {
            modelContext.processPendingChanges()
            modelContext.rollback()
            // SwiftData rollback doesn't reliably restore registered property values
            // synchronously. Restore the UI's values as well as cancelling the write.
            workout.sessionTitle = originalTitle
            workout.date = originalDate
            workout.duration = originalDuration
            workout.healthSyncStatus = originalStatus
            workout.healthSyncLastError = originalError
            workout.exercises = originalExercises
            workout.cardioEntries = originalCardio
            throw error
        }
    }

    private static func validate(_ value: Double, rule: NumberEntryRule) throws {
        if let message = rule.problem(value) {
            throw NSError(domain: "Form.Input", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private static func validateCardio(_ entries: [CardioDraft]) throws {
        for entry in entries {
            for field in entry.numberFields { try validate(field.value, rule: field.rule) }
        }
    }
}
