import SwiftUI

struct ActiveWorkoutHeader: View {
    let index: String
    let progress: String
    let close: () -> Void
    let requestDiscard: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("session in progress")
                    .font(.system(.subheadline, design: .default))
                Text(progress)
                    .font(.system(.caption2, design: .default))
                    .foregroundStyle(InkPalette.softInk.opacity(0.76))
                    .monospacedDigit()
            }
            .padding(.leading, 20)
            Spacer()
            Button("Close", action: close)
                .font(AtelierType.script(16))
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
            VStack(alignment: .leading, spacing: 10) {
                Text(draft.template.name).font(AtelierType.script(38))
                Text("\(draft.template.sets) sets · \(draft.template.minimumRepetitions)–\(draft.template.maximumRepetitions) \(draft.template.recordsTime ? "sec" : "reps")" + (draft.id == "reverse-lunge" ? " / side" : ""))
                    .font(.subheadline).foregroundStyle(InkPalette.softInk)
                PaperVignette(name: draft.template.assetName, height: 210)
            }.frame(maxWidth: .infinity, alignment: .leading)

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

                    HStack {
                        Text("set").frame(width: 40, alignment: .leading)
                        Text((draft.template.recordsLoad ? draft.template.loadLabel : "load").lowercased())
                            .frame(maxWidth: .infinity)
                        Text(draft.template.recordsTime ? "sec" : "reps")
                            .frame(maxWidth: .infinity)
                        Color.clear.frame(width: 52, height: 1)
                    }
                    .font(.system(.caption2, design: .default))
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

                    DisclosureGroup("Set options") {
                    Button(action: applyFirstWorkingSetToRemaining) {
                        Text("apply first set to remaining")
                            .font(AtelierType.script(16))
                            .foregroundStyle(InkPalette.cinnabar)
                            .frame(maxWidth: .infinity, minHeight: 42)
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
                        Text("add another set")
                            .font(AtelierType.script(16))
                            .frame(maxWidth: .infinity, minHeight: 46)
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
                            .font(AtelierType.script(16))
                            .foregroundStyle(InkPalette.cinnabar)
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.horizontal, 10)
                    .padding(.bottom, 9)
                    }.font(.subheadline).padding(.horizontal, 14).padding(.top, 10)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 8)
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
