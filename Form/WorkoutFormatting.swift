import Foundation

enum WorkoutValueFormatter {
    static func decimal(
        _ value: Double,
        fractionDigits: ClosedRange<Int> = 0...2
    ) -> String {
        value.formatted(.number.precision(.fractionLength(fractionDigits)))
    }

    static func weight(_ value: Double) -> String {
        value.formatted(
            .number.precision(.fractionLength(value.rounded() == value ? 0 : 1))
        )
    }

    static func durationMinutes(_ duration: TimeInterval) -> String {
        "\(max(1, Int(duration / 60))) min"
    }

    static func setText(
        weight: Double,
        repetitions: Int,
        template: ExerciseTemplate,
        includeUnit: Bool = true
    ) -> String {
        setText(
            weight: weight,
            repetitions: repetitions,
            measurement: template.measurement,
            usesPerHandLoad: template.usesPerHandLoad,
            includeUnit: includeUnit
        )
    }

    static func setText(
        weight: Double,
        repetitions: Int,
        measurement: ExerciseTemplate.Measurement,
        usesPerHandLoad: Bool = false,
        includeUnit: Bool = true
    ) -> String {
        switch measurement {
        case .weighted:
            let suffix: String
            if !includeUnit {
                suffix = ""
            } else if usesPerHandLoad {
                suffix = " kg / hand"
            } else {
                suffix = " kg"
            }
            return "\(self.weight(weight))\(suffix) × \(repetitions)"
        case .weightedTimed:
            let suffix = includeUnit ? " kg / hand" : ""
            return "\(self.weight(weight))\(suffix) × \(repetitions) sec"
        case .bodyweight:
            return "\(repetitions) reps"
        case .timed:
            return "\(repetitions) sec"
        }
    }

    static func setText(
        _ set: SetRecord,
        template: ExerciseTemplate?,
        includeUnit: Bool = true
    ) -> String {
        let measurement = template?.measurement
            ?? (set.weight > 0 ? .weighted : .bodyweight)
        return setText(
            weight: set.weight,
            repetitions: set.repetitions,
            measurement: measurement,
            usesPerHandLoad: template?.usesPerHandLoad ?? false,
            includeUnit: includeUnit
        )
    }

    static func rest(_ seconds: Int) -> String {
        if seconds % 60 == 0 {
            return "\(seconds / 60) min"
        }
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

/// An optional factual highlight. Routine sessions need only a save confirmation.
enum SessionObservation {
    static func message(for record: WorkoutRecord, in history: [WorkoutRecord]) -> String? {
        let earlier = history.filter { $0.date < record.date }
        for exercise in record.exercises.sorted(by: { $0.order < $1.order }) {
            guard let template = WorkoutCatalog.exercise(for: exercise) else { continue }
            let currentSets = workingSets(exercise)
            guard !currentSets.isEmpty else { continue }
            let previousExercises = earlier.sorted { $0.date > $1.date }.compactMap { workout in
                workout.exercises.first {
                    WorkoutCatalog.stableExerciseID(for: $0) == template.id
                        && !workingSets($0).isEmpty
                }
            }
            guard let previous = previousExercises.first else { continue }
            if template.recordsLoad {
                let previousLoad = previousExercises.flatMap { workingSets($0) }.map(\.weight).max() ?? 0
                let load = currentSets.map(\.weight).max() ?? 0
                if load > previousLoad && load > 0 {
                    let unit = template.usesPerHandLoad ? "kg per hand" : "kg"
                    return "\(exercise.name): your heaviest recorded load, \(WorkoutValueFormatter.weight(load)) \(unit)."
                }
                // Compare the best set at the same load, so heavier or lighter
                // sets cannot produce an unsupported repetition comparison.
                guard let top = currentSets.max(by: {
                    $0.weight == $1.weight ? $0.repetitions < $1.repetitions : $0.weight < $1.weight
                }), top.weight > 0,
                let previousReps = workingSets(previous).filter({ $0.weight == top.weight }).map(\.repetitions).max()
                else { continue }
                let difference = top.repetitions - previousReps
                if difference > 0 {
                    let amount = template.recordsTime
                        ? "\(difference) more second\(difference == 1 ? "" : "s")"
                        : "\(difference) more rep\(difference == 1 ? "" : "s")"
                    let unit = template.usesPerHandLoad ? "kg per hand" : "kg"
                    return "\(exercise.name): \(amount) at \(WorkoutValueFormatter.weight(top.weight)) \(unit) than last session."
                }
            } else {
                let best = currentSets.map(\.repetitions).max() ?? 0
                let previousBest = previousExercises.flatMap { workingSets($0) }.map(\.repetitions).max() ?? 0
                if best > previousBest {
                    let unit = template.recordsTime ? "sec" : "reps"
                    return "\(exercise.name): your best recorded set, \(best) \(unit)."
                }
            }
        }
        for entry in record.cardioEntries.sorted(by: { $0.order < $1.order }) {
            let previousDurations = earlier.flatMap(\.cardioEntries)
                .filter { $0.kind == entry.kind && $0.durationMinutes > 0 }
                .map(\.durationMinutes)
            if let previousBest = previousDurations.max(), entry.durationMinutes > previousBest {
                return "\(entry.kind.title): your longest recorded entry, \(WorkoutValueFormatter.decimal(entry.durationMinutes)) min."
            }
        }
        return nil
    }

    private static func workingSets(_ exercise: ExerciseRecord) -> [SetRecord] {
        exercise.sets.filter { $0.kind == .working && $0.repetitions > 0 }
    }
}
