import Foundation
import SwiftData

@MainActor
enum WorkoutRepository {
    static func saveCompletedSession(
        _ session: WorkoutSessionState,
        in modelContext: ModelContext
    ) throws -> WorkoutRecord {
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
                    weight: max(0, set.weight),
                    repetitions: max(0, set.repetitions),
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
}
