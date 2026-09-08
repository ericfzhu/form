import SwiftData
import SwiftUI

struct WorkoutCompletionView: View {
    let record: WorkoutRecord
    let done: () -> Void
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]

    private var completedExercises: [ExerciseRecord] {
        record.exercises
            .filter { $0.sets.contains { $0.kind == .working } }
            .sorted { $0.order < $1.order }
    }

    private var completedSetCount: Int {
        completedExercises.reduce(0) {
            $0 + $1.sets.filter { $0.kind == .working }.count
        }
    }

    private var cardioMinutes: Int {
        Int(record.cardioEntries.reduce(0) { $0 + $1.durationMinutes })
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    Text("a little more\nthan before.").font(AtelierType.script(42))
                    PaperVignette(name: "finished", height: 230)
                    HStack { Text("Time moving"); Spacer(); Text(WorkoutValueFormatter.durationMinutes(record.duration)) }
                    HStack { Text("Strength"); Spacer(); Text("\(completedSetCount) set\(completedSetCount == 1 ? "" : "s")") }
                    if cardioMinutes > 0 {
                        HStack { Text("Cardio"); Spacer(); Text("\(cardioMinutes) min") }
                    }
                    Text("and now, the rest of your day.")
                        .font(AtelierType.script(22)).foregroundStyle(InkPalette.softInk).padding(.vertical, 12)
                    DisclosureGroup("View session") {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("movements")
                            .font(.system(.body, design: .default))
                            .foregroundStyle(InkPalette.ink)
                            .padding(.bottom, 8)

                        ForEach(completedExercises) { exercise in
                            completionRow(exercise)
                            if exercise.persistentModelID != completedExercises.last?.persistentModelID {
                                InkDivider()
                            }
                        }
                    }

                    }

                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 104)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            InkPrimaryButton(title: "Done", action: done)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(InkPalette.paper.opacity(0.95))
        }
    }

    private func summaryMetric(_ value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(.title2, design: .default))
                .monospacedDigit()
            Text(label.lowercased())
                .font(.system(.caption2, design: .default))
                .foregroundStyle(InkPalette.softInk)
        }
        .frame(maxWidth: .infinity)
    }

    private func completionRow(_ exercise: ExerciseRecord) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.name)
                    .font(.system(.body, design: .default))
                Text(setSummary(exercise))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(InkPalette.softInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                if let comparison = comparison(for: exercise) {
                    Text(comparison)
                        .font(.system(.caption2, design: .default, weight: .semibold))
                        .foregroundStyle(InkPalette.cinnabar)
                }
            }
            Spacer(minLength: 8)
            let records = personalRecords(for: exercise)
            if !records.isEmpty {
                VStack(alignment: .trailing, spacing: 3) {
                    ForEach(records.prefix(2)) { record in
                        Text(record.shortTitle)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(InkPalette.cinnabar)
                    }
                }
            }
        }
        .frame(minHeight: 58)
    }

    private func setSummary(_ exercise: ExerciseRecord) -> String {
        let template = WorkoutCatalog.exercise(for: exercise)
        return exercise.sets.sorted { $0.order < $1.order }.map { set in
            let prefix = set.kind == .warmup ? "W " : ""
            return prefix + WorkoutValueFormatter.setText(set, template: template)
        }.joined(separator: " · ")
    }

    private func personalRecords(for exercise: ExerciseRecord) -> [ProgressRecord] {
        let performances = ProgressionEngine.performances(for: exercise, in: workouts)
        guard let performance = performances.first(where: {
            $0.id == record.persistentModelID
        }) else { return [] }
        let measurement = WorkoutCatalog.exercise(for: exercise)?.measurement
            ?? (exercise.sets.contains { $0.weight > 0 } ? .weighted : .bodyweight)
        return ProgressionEngine.personalRecords(
            for: performance,
            measurement: measurement,
            among: performances
        )
    }

    private func comparison(for exercise: ExerciseRecord) -> String? {
        let performances = ProgressionEngine.performances(for: exercise, in: workouts)
        guard let performance = performances.first(where: {
            $0.id == record.persistentModelID
        }) else { return nil }
        let measurement = WorkoutCatalog.exercise(for: exercise)?.measurement
            ?? (exercise.sets.contains { $0.weight > 0 } ? .weighted : .bodyweight)
        return ProgressionEngine.comparison(
            for: performance,
            measurement: measurement,
            among: performances
        )
    }
}

struct CompletionHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("done")
                .font(.system(.caption, design: .default))
                .foregroundStyle(InkPalette.softInk)
                .frame(width: 52, height: 52)
            Text("session complete")
                .font(.system(.subheadline, design: .default))
            Spacer()
        }
        .padding(.trailing, 16)
        .background { PaperSurface() }
    }
}
