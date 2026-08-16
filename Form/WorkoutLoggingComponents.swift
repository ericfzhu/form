import SwiftUI

struct ActiveWorkoutHeader: View {
    let index: String
    let progress: String
    let close: () -> Void
    let requestDiscard: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text(index)
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(InkPalette.cinnabar)
                .frame(width: 52, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text("SESSION IN PROGRESS")
                    .font(.system(.caption, design: .serif, weight: .semibold))
                    .tracking(1.5)
                Text(progress)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(InkPalette.softInk.opacity(0.76))
                    .monospacedDigit()
            }
            .padding(.leading, 12)
            Spacer()
            Button("Close", action: close)
                .font(.system(.subheadline, design: .serif))
                .frame(width: 58, height: 56)
                .buttonStyle(PressableButtonStyle())
            Menu {
                Button("Discard session", role: .destructive, action: requestDiscard)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 56)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Session options")
        }
        .background(InkPalette.paper)
        .overlay(alignment: .top) { InkDivider() }
        .overlay(alignment: .bottom) { ClassicalRule() }
    }
}

struct ExerciseLoggingCard: View {
    @Binding var draft: ExerciseDraft
    let previous: ExercisePerformance?
    let recommendation: ProgressionRecommendation?
    let isExpanded: Bool
    @FocusState.Binding var focusedInput: WorkoutInputField?
    let toggleExpanded: () -> Void
    let didUpdateSet: (Bool, SetKind) -> Void

    private var completedSetCount: Int {
        draft.sets.filter { $0.completed && $0.kind == .working }.count
    }

    private var isComplete: Bool { completedSetCount >= draft.template.sets }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: toggleExpanded) {
                HStack(spacing: 14) {
                    DemonstrationImage(assetName: draft.template.assetName)
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(draft.template.name)
                            .font(.system(.headline, design: .serif, weight: .semibold))
                            .multilineTextAlignment(.leading)
                        Text(draft.template.targetText)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(InkPalette.softInk)
                        Text(isComplete ? "DONE · \(completedSetCount) SETS" : "\(completedSetCount)/\(draft.template.sets) SETS")
                            .font(.caption2.weight(.semibold))
                            .tracking(1)
                            .foregroundStyle(isComplete ? InkPalette.cinnabar : InkPalette.softInk)
                            .monospacedDigit()
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(InkPalette.softInk.opacity(0.72))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    if let previous {
                        LastPerformanceSummary(
                            template: draft.template,
                            performance: previous,
                            recommendation: recommendation
                        )
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                    }

                    InkDivider().padding(.horizontal, 14).padding(.vertical, 5)

                    HStack {
                        Text("TYPE").frame(width: 40, alignment: .leading)
                        Text(draft.template.recordsLoad ? draft.template.loadLabel : "LOAD")
                            .frame(maxWidth: .infinity)
                        Text(draft.template.recordsTime ? "SEC" : "REPS")
                            .frame(maxWidth: .infinity)
                        Color.clear.frame(width: 52, height: 1)
                    }
                    .font(.caption2.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(InkPalette.softInk)
                    .padding(.horizontal, 14)
                    .padding(.top, 6)

                    ForEach($draft.sets) { $set in
                        SetLoggingRow(
                            exerciseID: draft.id,
                            index: setNumber(for: set.id),
                            measurement: draft.template.measurement,
                            set: $set,
                            focusedInput: $focusedInput,
                            canDelete: draft.sets.count > draft.template.sets || set.kind == .warmup,
                            delete: {
                                focusedInput = nil
                                withAnimation(.easeOut(duration: 0.18)) {
                                    draft.sets.removeAll { $0.id == set.id }
                                }
                            },
                            didToggleCompletion: didUpdateSet
                        )
                    }
                    .padding(.horizontal, 10)

                    Button(action: applyFirstWorkingSetToRemaining) {
                        Label("Apply first set to remaining", systemImage: "arrow.down.doc")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.7)
                            .textCase(.uppercase)
                            .foregroundStyle(InkPalette.cinnabar)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .overlay { Rectangle().stroke(InkPalette.cinnabar, lineWidth: 1) }
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(!canApplyFirstWorkingSet)
                    .opacity(canApplyFirstWorkingSet ? 1 : 0.4)
                    .padding(.horizontal, 10)

                    Button {
                        draft.sets.append(SetDraft(
                            weight: draft.sets.last?.weight ?? 0,
                            repetitions: draft.sets.last?.repetitions ?? draft.template.minimumRepetitions
                        ))
                    } label: {
                        Label("Add another set", systemImage: "plus")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(0.7)
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(InkPalette.raisedPaper)
                            .overlay { Rectangle().stroke(InkPalette.bronze.opacity(0.62), lineWidth: 1) }
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.horizontal, 10)

                    Button {
                        let first = draft.sets.first(where: { $0.kind == .working })
                            ?? SetDraft(weight: 0, repetitions: draft.template.minimumRepetitions)
                        let index = draft.sets.firstIndex(where: { $0.kind == .working }) ?? 0
                        draft.sets.insert(SetDraft(
                            weight: first.weight,
                            repetitions: first.repetitions,
                            kind: .warmup
                        ), at: index)
                    } label: {
                        Text("Add warm-up set")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.7)
                            .textCase(.uppercase)
                            .foregroundStyle(InkPalette.cinnabar)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .overlay { Rectangle().stroke(InkPalette.cinnabar, lineWidth: 1) }
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.horizontal, 10)
                    .padding(.bottom, 9)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .inkCard()
    }

    private func setNumber(for id: UUID) -> Int {
        guard let index = draft.sets.firstIndex(where: { $0.id == id }) else { return 1 }
        return draft.sets.prefix(index + 1).filter { $0.kind == .working }.count
    }

    private var canApplyFirstWorkingSet: Bool {
        guard let firstIndex = draft.sets.firstIndex(where: { $0.kind == .working }) else {
            return false
        }
        return draft.sets.indices.contains { index in
            index > firstIndex && draft.sets[index].kind == .working && !draft.sets[index].completed
        }
    }

    private func applyFirstWorkingSetToRemaining() {
        guard let firstIndex = draft.sets.firstIndex(where: { $0.kind == .working }) else { return }
        let reference = draft.sets[firstIndex]
        for index in draft.sets.indices where index > firstIndex
            && draft.sets[index].kind == .working
            && !draft.sets[index].completed {
            draft.sets[index].weight = reference.weight
            draft.sets[index].repetitions = reference.repetitions
        }
    }
}

