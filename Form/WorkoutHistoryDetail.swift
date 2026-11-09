import SwiftData
import SwiftUI

struct WorkoutHistoryDetail: View {
    let workout: WorkoutRecord
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        SavedWorkoutView(workout: workout, justSaved: false, done: { dismiss() })
            .background { InteractivePopGestureBridge(isEnabled: true) }
    }
}

/// A saved workout has one presentation, whether it was just finished or reopened.
struct SavedWorkoutView: View {
    let workout: WorkoutRecord
    var justSaved = false
    let done: () -> Void
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showingEditor = false
    @State private var details = false
    @State private var arrived = false

    private var completedExercises: [ExerciseRecord] {
        workout.exercises.filter { !$0.sets.isEmpty }.sorted { $0.order < $1.order }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(workout.displayName).font(.title2.weight(.bold)).accessibilityAddTraits(.isHeader)
                    Text(workout.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption).foregroundStyle(InkPalette.softInk)
                }
                CounterweightFigure(resting: true)
                    .frame(width: typeSize.isAccessibilitySize ? 130 : 172, height: typeSize.isAccessibilitySize ? 130 : 172)
                    .frame(maxWidth: .infinity)
                    .offset(y: justSaved && !arrived && !reduceMotion ? -8 : 0)
                    .scaleEffect(x: 1, y: justSaved && !arrived && !reduceMotion ? 1.04 : 1, anchor: .bottom)
                if justSaved {
                    HStack(spacing: 9) {
                        Image(systemName: "checkmark").font(.caption.weight(.medium))
                            .frame(width: 30, height: 30).background(InkPalette.salvia, in: Circle())
                            .scaleEffect(arrived || reduceMotion ? 1 : 0.8)
                        Text("Saved").font(.subheadline)
                    }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
                }
                Text(SessionRecordSummary.text(for: workout))
                    .font(.subheadline).foregroundStyle(InkPalette.softInk)
                    .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                Button {
                    withAnimation(reduceMotion ? nil : CounterweightMotion.disclosure) { details.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Text(details ? "Hide details" : "View details")
                        Image(systemName: "chevron.down").rotationEffect(.degrees(details ? 180 : 0))
                    }.font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(PressableButtonStyle()).accessibilityValue(details ? "Expanded" : "Collapsed")
                if details {
                    VStack(alignment: .leading, spacing: 20) {
                        if completedExercises.isEmpty && workout.cardioEntries.isEmpty {
                            Text("No sets or cardio recorded.").font(.subheadline)
                        }
                        ForEach(completedExercises) { exercise in
                            if let template = WorkoutCatalog.exercise(for: exercise) {
                                NavigationLink(value: template) {
                                    HistoryExerciseCard(exercise: exercise, records: records(for: exercise))
                                }.buttonStyle(PressableButtonStyle())
                            } else {
                                HistoryExerciseCard(exercise: exercise, records: records(for: exercise))
                            }
                            InkDivider()
                        }
                        ForEach(workout.cardioEntries.sorted { $0.order < $1.order }) { entry in
                            HStack(spacing: 14) {
                                DemonstrationImage(assetName: "walk").frame(width: 54, height: 54)
                                CardioHistoryCard(entry: entry)
                            }
                        }
                        Text(workout.healthSyncStatus.title).font(.caption).foregroundStyle(InkPalette.softInk)
                    }.transition(CounterweightMotion.transition(reduced: reduceMotion))
                }
            }
            .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 32)
        }
        .background(PaperBackground())
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            InkPrimaryButton(title: "Done", action: done)
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(InkPalette.paper)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                FormWordmark()
                Spacer()
                CounterweightIconButton(symbol: "arrow.left", label: "Back", action: done)
                CounterweightControl(title: "Edit", symbol: "pencil") { showingEditor = true }
            }.buttonStyle(PressableButtonStyle()).padding(.horizontal, 24)
                .background(InkPalette.paper)
        }
        .fullScreenCover(isPresented: $showingEditor) { WorkoutEditorView(workout: workout) }
        .onAppear {
            guard justSaved, !arrived else { return }
            withAnimation(reduceMotion ? nil : CounterweightMotion.settle) { arrived = true }
        }
    }

    private func records(for exercise: ExerciseRecord) -> [ProgressRecord] {
        let performances = ProgressionEngine.performances(for: exercise, in: workouts)
        guard let performance = performances.first(where: { $0.id == workout.persistentModelID }) else { return [] }
        let measurement = WorkoutCatalog.exercise(for: exercise)?.measurement ?? (exercise.sets.contains { $0.weight > 0 } ? .weighted : .bodyweight)
        return ProgressionEngine.personalRecords(for: performance, measurement: measurement, among: performances)
    }
}
struct HistoryExerciseCard: View {
    let exercise: ExerciseRecord
    let records: [ProgressRecord]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                DemonstrationImage(assetName: exercise.assetName)
                    .frame(width: 86, height: 86)
                VStack(alignment: .leading, spacing: 7) {
                    Text(exercise.name)
                        .font(.system(.body, design: .default))
                    if !records.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(records.prefix(2)) { record in
                                Text(record.shortTitle)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(InkPalette.cinnabar)
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(.vertical, 11)
            ForEach(exercise.sets.sorted { $0.order < $1.order }) { set in
                HStack {
                    Text(set.kind == .warmup ? "Warm-up" : "Set \(workingSetNumber(for: set))")
                        .font(.system(.body, design: .default))
                        .foregroundStyle(set.kind == .warmup ? InkPalette.cinnabar : InkPalette.softInk)
                    Spacer()
                    Text(WorkoutValueFormatter.setText(
                        set,
                        template: WorkoutCatalog.exercise(for: exercise)
                    ))
                    .font(.body.monospacedDigit().weight(.semibold))
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 46)
                .padding(.vertical, 6)
            }
        }
        .inkCard()
    }

    private func workingSetNumber(for set: SetRecord) -> Int {
        exercise.sets.filter { $0.kind == .working && $0.order <= set.order }.count
    }
}

struct CardioHistoryCard: View {
    let entry: CardioRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(entry.kind.title)
                .font(.system(.headline, design: .default, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
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
        .padding(.vertical, 12)
        .inkCard()
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(InkPalette.softInk)
            Text(value).font(.subheadline.monospacedDigit().weight(.semibold))
        }
        .accessibilityElement(children: .combine)
    }
}
