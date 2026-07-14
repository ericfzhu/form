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
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(InkPalette.cinnabar)
                                .frame(width: 9, height: 9)
                            Text("IN PROGRESS")
                                .font(.caption.weight(.semibold))
                                .tracking(2.6)
                                .foregroundStyle(InkPalette.softInk)
                        }
                        Text("Move with control.")
                            .font(.system(size: 30, weight: .semibold, design: .serif))
                            .foregroundStyle(InkPalette.ink)
                        InkDivider().padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 2)

                    ForEach($drafts) { $draft in
                        ExerciseLoggingCard(draft: $draft) {
                            restEnd = Date().addingTimeInterval(90)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, restEnd == nil ? 96 : 158)
            }
        }
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(InkPalette.paper.opacity(0.95), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { showingCancelConfirmation = true }
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(InkPalette.ink)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 9) {
                if let restEnd {
                    RestTimer(end: restEnd) {
                        self.restEnd = nil
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                InkPrimaryButton(title: "Finish session", action: finishWorkout)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(InkPalette.paper.opacity(0.95))
            .animation(.easeOut(duration: 0.2), value: restEnd)
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
            HStack(spacing: 15) {
                DemonstrationImage(assetName: draft.template.assetName)
                    .frame(width: 94, height: 94)

                VStack(alignment: .leading, spacing: 6) {
                    Text(draft.template.name)
                        .font(.system(.headline, design: .serif, weight: .semibold))
                        .foregroundStyle(InkPalette.ink)
                    Text(draft.template.targetText)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(InkPalette.softInk)
                }
                Spacer()
            }
            .padding(11)

            InkDivider()
                .padding(.horizontal, 14)
                .padding(.vertical, 5)

            HStack {
                Text("SET")
                    .frame(width: 36, alignment: .leading)
                Text(draft.template.measurement == .weighted ? "KG" : "LOAD")
                    .frame(maxWidth: .infinity)
                Text(draft.template.measurement == .timed ? "SEC" : "REPS")
                    .frame(maxWidth: .infinity)
                Color.clear.frame(width: 44, height: 1)
            }
            .font(.caption2.weight(.semibold))
            .tracking(1.2)
            .foregroundStyle(InkPalette.softInk)
            .padding(.horizontal, 14)
            .padding(.top, 6)

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
                draft.sets.append(
                    SetDraft(
                        weight: draft.sets.last?.weight ?? 0,
                        repetitions: draft.sets.last?.repetitions ?? draft.template.minimumRepetitions
                    )
                )
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add another set")
                }
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(InkPalette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, 10)
            .padding(.bottom, 9)
        }
        .inkCard()
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
                .foregroundStyle(InkPalette.softInk)
                .frame(width: 36, alignment: .leading)

            if measurement == .weighted {
                TextField("0", value: $set.weight, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .inkInput()
            } else {
                Text("BODY")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(InkPalette.softInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(InkPalette.paper.opacity(0.45))
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(InkPalette.ink.opacity(0.28))
                            .frame(height: 1)
                    }
            }

            TextField("0", value: $set.repetitions, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .inkInput()

            Button {
                set.completed.toggle()
                if set.completed { didComplete() }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(InkPalette.ink.opacity(set.completed ? 0 : 0.28), lineWidth: 1)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(set.completed ? InkPalette.cinnabar : .clear)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(InkPalette.paper)
                        .scaleEffect(set.completed ? 1 : 0.25)
                        .opacity(set.completed ? 1 : 0)
                        .blur(radius: set.completed ? 0 : 4)
                }
                .frame(width: 42, height: 42)
                .animation(.easeOut(duration: 0.2), value: set.completed)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(set.completed ? "Mark incomplete" : "Mark complete")
        }
        .padding(.vertical, 5)
    }
}

private struct InkInput: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body.monospacedDigit().weight(.medium))
            .foregroundStyle(InkPalette.ink)
            .frame(height: 42)
            .background(InkPalette.paper.opacity(0.45))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(InkPalette.ink.opacity(0.28))
                    .frame(height: 1)
            }
    }
}

private extension View {
    func inkInput() -> some View {
        modifier(InkInput())
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
                        .font(.caption2.weight(.semibold))
                        .tracking(1.8)
                        .foregroundStyle(InkPalette.softInk)
                    Text(timeString(remaining))
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .foregroundStyle(InkPalette.ink)
                }
                Spacer()
                Button("Skip", action: cancel)
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .foregroundStyle(InkPalette.ink)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, 16)
            .frame(height: 64)
            .inkCard()
            .onChange(of: remaining) { _, value in
                if value == 0 { cancel() }
            }
        }
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
