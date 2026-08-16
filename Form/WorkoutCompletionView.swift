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
                    Text(record.date.formatted(date: .long, time: .shortened).uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(1.5)
                        .foregroundStyle(InkPalette.softInk)

                    HStack(spacing: 0) {
                        summaryMetric("\(max(1, Int(record.duration / 60)))", label: "MINUTES")
                        summaryMetric("\(completedExercises.count)", label: "MOVEMENTS")
                        summaryMetric("\(completedSetCount)", label: "SETS")
                    }
                    .padding(.vertical, 15)
                    .background(InkPalette.raisedPaper)
                    .overlay { Rectangle().stroke(InkPalette.ink, lineWidth: 1) }

                    if record.hasTrainingData {
                        HStack(spacing: 10) {
                            Image(systemName: record.healthSyncStatus == .synced ? "heart.fill" : "heart")
                                .foregroundStyle(InkPalette.cinnabar)
                            Text(record.healthSyncStatus.title)
                                .font(.system(.caption, design: .serif, weight: .semibold))
                                .foregroundStyle(record.healthSyncStatus == .failed
                                    ? InkPalette.cinnabar
                                    : InkPalette.softInk)
                            Spacer()
                        }
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text("MOVEMENTS")
                            .font(.caption2.weight(.semibold))
                            .tracking(1.8)
                            .foregroundStyle(InkPalette.softInk)
                            .padding(.bottom, 8)

                        ForEach(completedExercises) { exercise in
                            completionRow(exercise)
                            if exercise.persistentModelID != completedExercises.last?.persistentModelID {
                                InkDivider()
                            }
                        }
                    }

                    if cardioMinutes > 0 {
                        HStack {
                            Text("CARDIO")
                                .font(.caption2.weight(.semibold))
                                .tracking(1.8)
                                .foregroundStyle(InkPalette.softInk)
                            Spacer()
                            Text("\(cardioMinutes) min")
                                .font(.subheadline.monospacedDigit().weight(.semibold))
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
                .font(.system(.title2, design: .serif, weight: .semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption2.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(InkPalette.softInk)
        }
        .frame(maxWidth: .infinity)
    }

    private func completionRow(_ exercise: ExerciseRecord) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.name)
                    .font(.system(.body, design: .serif, weight: .semibold))
                Text(setSummary(exercise))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(InkPalette.softInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                if let comparison = comparison(for: exercise) {
                    Text(comparison)
                        .font(.system(.caption2, design: .serif, weight: .semibold))
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
                            .tracking(0.7)
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
            Text("✓")
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(InkPalette.raisedPaper)
                .frame(width: 52, height: 52)
                .background(Rectangle().fill(InkPalette.cinnabar))
            Text("SESSION COMPLETE")
                .font(.system(.caption, design: .serif, weight: .semibold))
                .tracking(1.6)
            Spacer()
        }
        .padding(.trailing, 16)
        .background { PaperSurface() }
        .overlay(alignment: .bottom) { ClassicalRule() }
    }
}

