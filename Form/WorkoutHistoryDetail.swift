import SwiftData
import SwiftUI

struct WorkoutHistoryDetail: View {
    let workout: WorkoutRecord
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]
    @State private var showingEditor = false

    private var completedExercises: [ExerciseRecord] {
        workout.exercises
            .filter { $0.sets.contains { $0.kind == .working } }
            .sorted { $0.order < $1.order }
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(spacing: 14) {
                    HStack {
                        Text(workout.date.formatted(date: .long, time: .omitted).uppercased())
                            .font(.caption.weight(.semibold))
                            .tracking(1.8)
                            .foregroundStyle(InkPalette.softInk)
                        Spacer()
                        Text(workout.healthSyncStatus.title.uppercased())
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundStyle(InkPalette.cinnabar)
                    }
                    InkDivider()

                    ForEach(completedExercises) { exercise in
                        if let template = WorkoutCatalog.exercise(for: exercise) {
                            NavigationLink(value: template) {
                                HistoryExerciseCard(exercise: exercise, records: records(for: exercise))
                            }
                            .buttonStyle(PressableButtonStyle())
                        } else {
                            HistoryExerciseCard(exercise: exercise, records: records(for: exercise))
                        }
                    }

                    if !workout.cardioEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CARDIO")
                                .font(.caption2.weight(.semibold))
                                .tracking(1.8)
                                .foregroundStyle(InkPalette.softInk)
                            ForEach(workout.cardioEntries.sorted { $0.order < $1.order }) {
                                CardioHistoryCard(entry: $0)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background { InteractivePopGestureBridge(isEnabled: true) }
        .safeAreaInset(edge: .top, spacing: 0) {
            InkTextHeader(
                title: workout.displayName.uppercased(),
                leadingTitle: "Back",
                leadingAction: { dismiss() },
                trailingTitle: "Edit",
                trailingAction: { showingEditor = true }
            )
        }
        .fullScreenCover(isPresented: $showingEditor) {
            WorkoutEditorView(workout: workout)
        }
    }

    private func records(for exercise: ExerciseRecord) -> [ProgressRecord] {
        let performances = ProgressionEngine.performances(for: exercise, in: workouts)
        guard let performance = performances.first(where: {
            $0.id == workout.persistentModelID
        }) else { return [] }
        let measurement = WorkoutCatalog.exercise(for: exercise)?.measurement
            ?? (exercise.sets.contains { $0.weight > 0 } ? .weighted : .bodyweight)
        return ProgressionEngine.personalRecords(
            for: performance,
            measurement: measurement,
            among: performances
        )
    }
}

private struct HistoryExerciseCard: View {
    let exercise: ExerciseRecord
    let records: [ProgressRecord]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                DemonstrationImage(assetName: exercise.assetName)
                    .frame(width: 86, height: 86)
                VStack(alignment: .leading, spacing: 7) {
                    Text(exercise.name)
                        .font(.system(.headline, design: .serif, weight: .semibold))
                    if !records.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(records.prefix(2)) { record in
                                Text(record.shortTitle)
                                    .font(.caption2.weight(.bold))
                                    .tracking(0.8)
                                    .foregroundStyle(InkPalette.cinnabar)
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(11)
            InkDivider().padding(.horizontal, 14).padding(.vertical, 3)
            ForEach(exercise.sets.sorted { $0.order < $1.order }) { set in
                HStack {
                    Text(set.kind == .warmup ? "Warm-up" : "Set \(workingSetNumber(for: set))")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(set.kind == .warmup ? InkPalette.cinnabar : InkPalette.softInk)
                    Spacer()
                    Text(WorkoutValueFormatter.setText(
                        set,
                        template: WorkoutCatalog.exercise(for: exercise)
                    ))
                    .font(.body.monospacedDigit().weight(.semibold))
                }
                .padding(.horizontal, 16)
                .frame(height: 46)
            }
        }
        .inkCard()
    }

    private func workingSetNumber(for set: SetRecord) -> Int {
        exercise.sets.filter { $0.kind == .working && $0.order <= set.order }.count
    }
}

private struct CardioHistoryCard: View {
    let entry: CardioRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(entry.kind.title)
                .font(.system(.headline, design: .serif, weight: .semibold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), alignment: .leading)], spacing: 12) {
                metric("\(WorkoutValueFormatter.decimal(entry.durationMinutes)) min", "TIME")
                if entry.distanceKilometers > 0 {
                    metric("\(WorkoutValueFormatter.decimal(entry.distanceKilometers)) km", "DISTANCE")
                }
                if entry.averageSpeed > 0 {
                    metric("\(WorkoutValueFormatter.decimal(entry.averageSpeed)) km/h", "SPEED")
                }
                if entry.kind.supportsIncline && entry.incline > 0 {
                    metric("\(WorkoutValueFormatter.decimal(entry.incline))%", "INCLINE")
                }
            }
        }
        .padding(16)
        .inkCard()
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .tracking(0.9)
                .foregroundStyle(InkPalette.softInk)
            Text(value).font(.subheadline.monospacedDigit().weight(.semibold))
        }
    }
}
