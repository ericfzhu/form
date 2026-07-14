import SwiftUI
import SwiftData

private struct SetDraft: Identifiable {
    let id = UUID()
    var weight: Double
    var repetitions: Int
    var completed = false
}

private struct ExerciseDraft: Identifiable {
    let id: String
    let template: ExerciseTemplate
    var sets: [SetDraft]
}

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var history: [WorkoutRecord]

    let routine: RoutineTemplate
    @State private var startedAt = Date()
    @State private var drafts: [ExerciseDraft]
    @State private var restEnd: Date?
    @State private var showingCancelConfirmation = false

    init(routine: RoutineTemplate) {
        self.routine = routine
        _drafts = State(initialValue: routine.exercises.map { exercise in
            ExerciseDraft(
                id: exercise.id,
                template: exercise,
                sets: (0..<exercise.sets).map { _ in
                    SetDraft(weight: 0, repetitions: exercise.minimumRepetitions)
                }
            )
        })
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach($drafts) { $draft in
                    ExerciseLoggingCard(draft: $draft) {
                        restEnd = Date().addingTimeInterval(90)
                    }
                }
            }
            .padding(20)
            .padding(.bottom, restEnd == nil ? 90 : 146)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { showingCancelConfirmation = true }
                    .foregroundStyle(.primary)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                if let restEnd {
                    RestTimer(end: restEnd) {
                        self.restEnd = nil
                    }
                }

                Button(action: finishWorkout) {
                    Text("Finish workout")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(.black, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .confirmationDialog("Discard this workout?", isPresented: $showingCancelConfirmation) {
            Button("Discard workout", role: .destructive) { dismiss() }
            Button("Keep training", role: .cancel) {}
        }
        .onAppear(perform: prefillFromHistory)
    }

    private func prefillFromHistory() {
        for draftIndex in drafts.indices {
            guard let previous = history
                .flatMap(\.exercises)
                .first(where: { $0.name == drafts[draftIndex].template.name }) else { continue }

            let previousSets = previous.sets.sorted { $0.order < $1.order }
            for setIndex in drafts[draftIndex].sets.indices where setIndex < previousSets.count {
                drafts[draftIndex].sets[setIndex].weight = previousSets[setIndex].weight
                drafts[draftIndex].sets[setIndex].repetitions = previousSets[setIndex].repetitions
            }
        }
    }

    private func finishWorkout() {
        let record = WorkoutRecord(
            date: startedAt,
            routineName: routine.name,
            duration: Date().timeIntervalSince(startedAt)
        )

        record.exercises = drafts.enumerated().map { exerciseIndex, draft in
            let exercise = ExerciseRecord(
                name: draft.template.name,
                assetName: draft.template.assetName,
                order: exerciseIndex
            )
            exercise.sets = draft.sets.enumerated().compactMap { setIndex, set in
                guard set.completed else { return nil }
                return SetRecord(order: setIndex, weight: set.weight, repetitions: set.repetitions)
            }
            return exercise
        }

        modelContext.insert(record)
        try? modelContext.save()
        dismiss()
    }
}

private struct ExerciseLoggingCard: View {
    @Binding var draft: ExerciseDraft
    let didCompleteSet: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                DemonstrationImage(assetName: draft.template.assetName)
                    .frame(width: 82, height: 82)

                VStack(alignment: .leading, spacing: 5) {
                    Text(draft.template.name)
                        .font(.headline)
                    Text(draft.template.targetText)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)

            Divider()
                .padding(.horizontal, 12)

            HStack {
                Text("SET")
                    .frame(width: 36, alignment: .leading)
                Text(draft.template.measurement == .weighted ? "KG" : "LOAD")
                    .frame(maxWidth: .infinity)
                Text(draft.template.measurement == .timed ? "SEC" : "REPS")
                    .frame(maxWidth: .infinity)
                Color.clear.frame(width: 44, height: 1)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.top, 12)

            ForEach(Array(draft.sets.indices), id: \.self) { index in
                SetLoggingRow(
                    index: index + 1,
                    measurement: draft.template.measurement,
                    set: $draft.sets[index]
                ) {
                    didCompleteSet()
                }
            }
            .padding(.horizontal, 10)

            Button {
                draft.sets.append(SetDraft(weight: draft.sets.last?.weight ?? 0, repetitions: draft.sets.last?.repetitions ?? draft.template.minimumRepetitions))
            } label: {
                Label("Add set", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

private struct SetLoggingRow: View {
    let index: Int
    let measurement: ExerciseTemplate.Measurement
    @Binding var set: SetDraft
    let didComplete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index)")
                .font(.body.monospacedDigit().weight(.semibold))
                .frame(width: 36, alignment: .leading)

            if measurement == .weighted {
                TextField("0", value: $set.weight, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .inputSurface()
            } else {
                Text("BODY")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            TextField("0", value: $set.repetitions, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .inputSurface()

            Button {
                set.completed.toggle()
                if set.completed { didComplete() }
            } label: {
                Image(systemName: set.completed ? "checkmark" : "circle")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(set.completed ? .white : .secondary)
                    .frame(width: 42, height: 42)
                    .background(set.completed ? .black : Color(.secondarySystemGroupedBackground), in: Circle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(set.completed ? "Mark incomplete" : "Mark complete")
        }
        .padding(.vertical, 5)
    }
}

private struct InputSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body.monospacedDigit().weight(.medium))
            .frame(height: 42)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private extension View {
    func inputSurface() -> some View {
        modifier(InputSurface())
    }
}

private struct RestTimer: View {
    let end: Date
    let cancel: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(end.timeIntervalSince(context.date).rounded(.up)))
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("REST")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(timeString(remaining))
                        .font(.title3.monospacedDigit().weight(.bold))
                }
                Spacer()
                Button("Skip", action: cancel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, 16)
            .frame(height: 62)
            .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            .onChange(of: remaining) { _, value in
                if value == 0 { cancel() }
            }
        }
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
