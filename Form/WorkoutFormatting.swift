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
