import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct CoachingReport: Transferable {
    let markdown: String
    let generatedAt: Date

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { report in
            let date = report.generatedAt.formatted(
                .iso8601.year().month().day()
            )
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Form Coaching Report \(date)")
                .appendingPathExtension("md")
            try Data(report.markdown.utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

enum CoachingReportBuilder {
    static func build(
        from workouts: [WorkoutRecord],
        generatedAt: Date = Date()
    ) -> CoachingReport {
        let calendar = Calendar.current
        let periodStart = calendar.date(byAdding: .weekOfYear, value: -12, to: generatedAt)
            ?? .distantPast
        let included = workouts
            .filter { $0.date >= periodStart && $0.date <= generatedAt }
            .sorted { $0.date > $1.date }

        var lines = [
            "# Form coaching report",
            "",
            "- Generated: \(dateTime(generatedAt))",
            "- Period: \(shortDate(periodStart)) to \(shortDate(generatedAt))",
            "- Completed sessions: \(included.count)",
            "- Training time: \(totalMinutes(included)) minutes",
            "- Working sets: \(workingSetCount(included))",
            "- Recorded volume: \(weight(totalVolume(included))) kg",
            ""
        ]

        lines.append(contentsOf: programSection())
        lines.append(contentsOf: progressionSection(included))
        lines.append(contentsOf: sessionSection(included))

        return CoachingReport(
            markdown: lines.joined(separator: "\n"),
            generatedAt: generatedAt
        )
    }

    private static func programSection() -> [String] {
        var lines = [
            "## Current programme",
            ""
        ]

        for routine in WorkoutCatalog.routines {
            lines.append("### \(routine.name) — \(routine.focus)")
            for exercise in routine.exercises {
                lines.append(
                    "- \(exercise.name) (`\(exercise.id)`): "
                        + "\(exercise.targetText), \(restText(exercise.restSeconds)) rest"
                )
            }
            lines.append("")
        }
        return lines
    }

    private static func progressionSection(_ workouts: [WorkoutRecord]) -> [String] {
        var lines = [
            "## Exercise summary",
            ""
        ]

        for template in uniqueExercises {
            let appearances = workouts.compactMap { workout -> (Date, ExerciseRecord)? in
                guard let record = workout.exercises.first(where: {
                    WorkoutCatalog.stableExerciseID(for: $0) == template.id
                }), record.sets.contains(where: { $0.kind == .working }) else {
                    return nil
                }
                return (workout.date, record)
            }

            guard let latest = appearances.max(by: { $0.0 < $1.0 }) else {
                lines.append("- \(template.name) (`\(template.id)`): no completed working sets")
                continue
            }

            let latestSets = latest.1.sets
                .filter { $0.kind == .working }
                .sorted { $0.order < $1.order }
                .map { setDescription($0, measurement: template.measurement) }
                .joined(separator: "; ")

            lines.append(
                "- \(template.name) (`\(template.id)`): "
                    + "\(appearances.count) sessions; latest \(shortDate(latest.0)) — \(latestSets)"
            )
        }

        lines.append("")
        return lines
    }

    private static func sessionSection(_ workouts: [WorkoutRecord]) -> [String] {
        var lines = [
            "## Sessions",
            ""
        ]

        guard !workouts.isEmpty else {
            lines.append("No completed sessions in this period.")
            lines.append("")
            return lines
        }

        for workout in workouts {
            lines.append(
                "### \(shortDate(workout.date)) — \(workout.routineName)"
            )
            lines.append(
                "- Duration: \(max(1, Int(workout.duration / 60))) minutes"
            )

            for exercise in workout.exercises.sorted(by: { $0.order < $1.order }) {
                let exerciseID = WorkoutCatalog.stableExerciseID(for: exercise)
                let template = WorkoutCatalog.exercise(for: exercise)
                let sets = exercise.sets.sorted { $0.order < $1.order }

                if sets.isEmpty {
                    lines.append("- \(exercise.name) (`\(exerciseID)`): skipped")
                    continue
                }

                let setText = sets.map { set in
                    let kind = set.kind == .warmup ? "warm-up" : "working"
                    let measurement = template?.measurement
                        ?? (set.weight > 0 ? .weighted : .bodyweight)
                    return "\(kind) \(setDescription(set, measurement: measurement))"
                }
                .joined(separator: "; ")

                lines.append("- \(exercise.name) (`\(exerciseID)`): \(setText)")
            }

            for cardio in workout.cardioEntries.sorted(by: { $0.order < $1.order }) {
                var values = ["\(number(cardio.durationMinutes)) min"]
                if cardio.distanceKilometers > 0 {
                    values.append("\(number(cardio.distanceKilometers)) km")
                }
                if cardio.averageSpeed > 0 {
                    values.append("\(number(cardio.averageSpeed)) km/h")
                }
                if cardio.kind.supportsIncline, cardio.incline > 0 {
                    values.append("\(number(cardio.incline))% incline")
                }
                lines.append("- Cardio — \(cardio.kind.title): \(values.joined(separator: ", "))")
            }

            lines.append("")
        }

        return lines
    }

    private static var uniqueExercises: [ExerciseTemplate] {
        var seen = Set<String>()
        return WorkoutCatalog.routines
            .flatMap(\.exercises)
            .filter { seen.insert($0.id).inserted }
    }

    private static func workingSetCount(_ workouts: [WorkoutRecord]) -> Int {
        workouts.reduce(0) { workoutTotal, workout in
            workoutTotal + workout.exercises.reduce(0) { exerciseTotal, exercise in
                exerciseTotal + exercise.sets.filter { $0.kind == .working }.count
            }
        }
    }

    private static func totalMinutes(_ workouts: [WorkoutRecord]) -> Int {
        workouts.reduce(0) { $0 + max(1, Int($1.duration / 60)) }
    }

    private static func totalVolume(_ workouts: [WorkoutRecord]) -> Double {
        workouts.reduce(0) { workoutTotal, workout in
            workoutTotal + workout.exercises.reduce(0) { exerciseTotal, exercise in
                guard WorkoutCatalog.exercise(for: exercise)?.measurement != .weightedTimed else {
                    return exerciseTotal
                }
                return exerciseTotal + exercise.sets
                    .filter { $0.kind == .working }
                    .reduce(0) { $0 + $1.weight * Double($1.repetitions) }
            }
        }
    }

    private static func setDescription(
        _ set: SetRecord,
        measurement: ExerciseTemplate.Measurement
    ) -> String {
        switch measurement {
        case .weighted:
            "\(weight(set.weight)) kg × \(set.repetitions)"
        case .weightedTimed:
            "\(weight(set.weight)) kg / hand × \(set.repetitions) sec"
        case .bodyweight:
            "\(set.repetitions) reps"
        case .timed:
            "\(set.repetitions) sec"
        }
    }

    private static func restText(_ seconds: Int) -> String {
        if seconds % 60 == 0 {
            return "\(seconds / 60) min"
        }
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }

    private static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.abbreviated).day())
    }

    private static func dateTime(_ date: Date) -> String {
        date.formatted(
            .dateTime.year().month(.abbreviated).day().hour().minute()
        )
    }

    private static func weight(_ value: Double) -> String {
        value.formatted(
            .number.precision(.fractionLength(value.rounded() == value ? 0 : 1))
        )
    }

    private static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
