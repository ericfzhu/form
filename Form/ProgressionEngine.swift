import Charts
import SwiftData
import SwiftUI

struct PerformanceSetValue: Hashable {
    let weight: Double
    let repetitions: Int
}

struct ExercisePerformance: Identifiable, Hashable {
    let id: PersistentIdentifier
    let date: Date
    let sets: [PerformanceSetValue]

    var topSet: PerformanceSetValue? {
        sets.max {
            if $0.weight == $1.weight {
                return $0.repetitions < $1.repetitions
            }
            return $0.weight < $1.weight
        }
    }

    var bestRepetitions: Int { sets.map(\.repetitions).max() ?? 0 }
    var totalVolume: Double {
        sets.reduce(0) { $0 + $1.weight * Double($1.repetitions) }
    }
    var estimatedOneRepMax: Double {
        sets
            .filter { $0.weight > 0 && $0.repetitions > 0 }
            .map { $0.weight * (1 + Double($0.repetitions) / 30) }
            .max() ?? 0
    }
}

enum ProgressRecord: String, Identifiable {
    case load
    case estimatedOneRepMax
    case volume
    case repetitions
    case time

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .load: "LOAD PR"
        case .estimatedOneRepMax: "1RM PR"
        case .volume: "VOLUME PR"
        case .repetitions: "REP PR"
        case .time: "TIME PR"
        }
    }
}

struct ProgressionRecommendation {
    let title: String
    let detail: String
}

enum ProgressionEngine {
    static var loadIncrement: Double {
        let stored = UserDefaults.standard.double(forKey: "progression-load-increment")
        return stored > 0 ? stored : 2.5
    }

    static func performances(
        for template: ExerciseTemplate,
        in workouts: [WorkoutRecord]
    ) -> [ExercisePerformance] {
        performances(
            forExerciseID: template.id,
            legacyName: template.name,
            in: workouts
        )
    }

    static func performances(
        for record: ExerciseRecord,
        in workouts: [WorkoutRecord]
    ) -> [ExercisePerformance] {
        performances(
            forExerciseID: WorkoutCatalog.stableExerciseID(for: record),
            legacyName: record.name,
            in: workouts
        )
    }

    private static func performances(
        forExerciseID exerciseID: String,
        legacyName: String,
        in workouts: [WorkoutRecord]
    ) -> [ExercisePerformance] {
        workouts.compactMap { workout in
            guard let exercise = workout.exercises.first(where: {
                WorkoutCatalog.stableExerciseID(for: $0) == exerciseID
                    || ($0.exerciseID.isEmpty && $0.name == legacyName)
            }) else { return nil }

            let sets = exercise.sets
                .filter { $0.kind == .working }
                .sorted { $0.order < $1.order }
                .map { PerformanceSetValue(weight: $0.weight, repetitions: $0.repetitions) }
            guard !sets.isEmpty else { return nil }
            return ExercisePerformance(
                id: workout.persistentModelID,
                date: workout.date,
                sets: sets
            )
        }
        .sorted { $0.date > $1.date }
    }

    static func latestCompleted(
        for template: ExerciseTemplate,
        in workouts: [WorkoutRecord]
    ) -> ExercisePerformance? {
        performances(for: template, in: workouts).first
    }

    static func recommendation(
        for template: ExerciseTemplate,
        performances: [ExercisePerformance]
    ) -> ProgressionRecommendation? {
        let decision = ProgressionRules.decision(
            prescription: ProgressionPrescription(
                measurement: template.progressionMeasurement,
                prescribedSets: template.sets,
                minimumRepetitions: template.minimumRepetitions,
                maximumRepetitions: template.maximumRepetitions,
                loadIncrement: loadIncrement
            ),
            performances: performances.map {
                ProgressionInputPerformance(sets: $0.sets.map {
                    ProgressionInputSet(weight: $0.weight, repetitions: $0.repetitions)
                })
            }
        )

        switch decision {
        case .increaseLoad(let load):
            return ProgressionRecommendation(
                title: "Increase to \(WorkoutValueFormatter.weight(load)) kg\(template.usesPerHandLoad ? " / hand" : "")",
                detail: template.measurement == .weightedTimed
                    ? "You held the current load for the full target time across every prescribed set."
                    : "You reached the top of the target range across every prescribed set."
            )
        case .reduceLoad(let load):
            return ProgressionRecommendation(
                title: "Consider \(WorkoutValueFormatter.weight(load)) kg\(template.usesPerHandLoad ? " / hand" : "")",
                detail: "The minimum target was missed in two consecutive sessions."
            )
        case .holdLoad(let load):
            return ProgressionRecommendation(
                title: "Keep \(WorkoutValueFormatter.weight(load)) kg\(template.usesPerHandLoad ? " / hand" : "")",
                detail: template.measurement == .weightedTimed
                    ? "Build every set toward \(template.maximumRepetitions) seconds before increasing the load."
                    : "Aim to add one repetition while staying inside the target range."
            )
        case .recordLoad:
            return ProgressionRecommendation(
                title: "Record the dumbbell load",
                detail: "Enter the weight of one dumbbell and carry for \(template.minimumRepetitions)–\(template.maximumRepetitions) seconds."
            )
        case .addRepetition:
            return ProgressionRecommendation(
                title: "Add one repetition",
                detail: "Keep the same movement quality and build toward \(template.maximumRepetitions) reps."
            )
        case .addTime:
            return ProgressionRecommendation(
                title: "Add a few seconds",
                detail: "Keep the same position and build toward \(template.maximumRepetitions) seconds."
            )
        case nil:
            return nil
        }
    }

    static func comparison(
        for current: ExercisePerformance,
        measurement: ExerciseTemplate.Measurement,
        among performances: [ExercisePerformance]
    ) -> String? {
        guard let previous = performances
            .filter({ $0.date < current.date })
            .max(by: { $0.date < $1.date }) else { return nil }

        switch measurement {
        case .weighted:
            let loadDelta = (current.topSet?.weight ?? 0) - (previous.topSet?.weight ?? 0)
            if loadDelta != 0 {
                return "\(loadDelta > 0 ? "+" : "")\(WorkoutValueFormatter.decimal(loadDelta)) kg"
            }
            let volumeDelta = current.totalVolume - previous.totalVolume
            if volumeDelta != 0 {
                return "\(volumeDelta > 0 ? "+" : "")\(Int(volumeDelta)) kg volume"
            }
            let repDelta = current.bestRepetitions - previous.bestRepetitions
            if repDelta != 0 {
                return "\(repDelta > 0 ? "+" : "")\(repDelta) reps"
            }
            return "Matched previous"
        case .weightedTimed:
            let loadDelta = (current.topSet?.weight ?? 0) - (previous.topSet?.weight ?? 0)
            if loadDelta != 0 {
                return "\(loadDelta > 0 ? "+" : "")\(WorkoutValueFormatter.decimal(loadDelta)) kg / hand"
            }
            let timeDelta = current.bestRepetitions - previous.bestRepetitions
            if timeDelta != 0 {
                return "\(timeDelta > 0 ? "+" : "")\(timeDelta) sec"
            }
            return "Matched previous"
        case .bodyweight, .timed:
            let delta = current.bestRepetitions - previous.bestRepetitions
            if delta == 0 { return "Matched previous" }
            return "\(delta > 0 ? "+" : "")\(delta) \(measurement == .timed ? "sec" : "reps")"
        }
    }

    static func personalRecords(
        for performance: ExercisePerformance,
        measurement: ExerciseTemplate.Measurement,
        among performances: [ExercisePerformance]
    ) -> [ProgressRecord] {
        let previous = performances.filter { $0.date < performance.date }
        guard !previous.isEmpty else { return [] }

        switch measurement {
        case .weighted:
            var records: [ProgressRecord] = []
            let previousLoad = previous.compactMap { $0.topSet?.weight }.max() ?? 0
            if (performance.topSet?.weight ?? 0) > previousLoad { records.append(.load) }
            if performance.estimatedOneRepMax > (previous.map(\.estimatedOneRepMax).max() ?? 0) {
                records.append(.estimatedOneRepMax)
            }
            if performance.totalVolume > (previous.map(\.totalVolume).max() ?? 0) {
                records.append(.volume)
            }
            return records
        case .weightedTimed:
            var records: [ProgressRecord] = []
            let previousLoad = previous.compactMap { $0.topSet?.weight }.max() ?? 0
            if (performance.topSet?.weight ?? 0) > previousLoad { records.append(.load) }
            if performance.bestRepetitions > (previous.map(\.bestRepetitions).max() ?? 0) {
                records.append(.time)
            }
            return records
        case .bodyweight:
            let previousBest = previous.map(\.bestRepetitions).max() ?? 0
            return performance.bestRepetitions > previousBest ? [.repetitions] : []
        case .timed:
            let previousBest = previous.map(\.bestRepetitions).max() ?? 0
            return performance.bestRepetitions > previousBest ? [.time] : []
        }
    }
}

