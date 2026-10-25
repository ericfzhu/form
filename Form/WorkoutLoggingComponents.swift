import SwiftUI

struct ActiveWorkoutHeader: View {
    let index: String
    let progress: String
    let requestFinish: () -> Void
    let pause: () -> Void
    let requestDiscard: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if typeSize.isAccessibilitySize {
                Text(progress).font(.caption2).foregroundStyle(InkPalette.softInk)
            }
            HStack(spacing: 12) {
                if !typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("session in progress").font(.subheadline)
                        Text(progress).font(.caption2).foregroundStyle(InkPalette.softInk)
                    }
                    Spacer(minLength: 0)
                }
                Button("Finish session", action: requestFinish)
                    .font(AtelierType.script(16))
                    .frame(minHeight: 44)
                    .buttonStyle(PressableButtonStyle())
                if typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                Menu {
                    Button("Pause and close", action: pause)
                    Button("Discard session", role: .destructive, action: requestDiscard)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 22))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Session options")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(InkPalette.paper)
    }
}

struct ExerciseLoggingCard: View {
    @Environment(\.dynamicTypeSize) private var typeSize
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

    private var workingSetCount: Int { draft.sets.filter { $0.kind == .working }.count }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                DemonstrationImage(assetName: draft.template.assetName)
                    .frame(width: 64, height: 70)
                VStack(alignment: .leading, spacing: 5) {
                    Text(draft.template.name).font(AtelierType.script(27))
                        .accessibilityAddTraits(.isHeader)
                    Text("\(completedSetCount)/\(workingSetCount) sets · \(draft.template.minimumRepetitions)–\(draft.template.maximumRepetitions) \(draft.template.recordsTime ? "sec" : "reps")" + (draft.id == "reverse-lunge" ? " / side" : ""))
                        .font(.caption).foregroundStyle(InkPalette.softInk)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ExerciseRestPicker(exercise: draft.template)
                .padding(.horizontal, 14)


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

                    if !typeSize.isAccessibilitySize {
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
                    }

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

                    DisclosureGroup("Movement notes") {
                        VStack(alignment: .leading, spacing: 10) {
                            PaperVignette(name: draft.template.assetName, height: 160)
                            Text("Leave about 2 reps in reserve.")
                            ForEach(draft.template.formCues, id: \.self) { Text($0) }
                            if draft.id == "reverse-lunge" { Text("Record repetitions per side.") }
                        }.font(.subheadline).padding(.vertical, 10)
                    }
                    .font(AtelierType.script(18)).padding(.horizontal, 14).padding(.top, 10)
                    .accessibilityLabel("\(draft.template.name), movement notes")

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
                        .accessibilityLabel("\(draft.template.name), set options")
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

private struct ExerciseRestPicker: View {
    @AppStorage private var seconds: Int
    private let exerciseName: String

    init(exercise: ExerciseTemplate) {
        exerciseName = exercise.name
        _seconds = AppStorage(wrappedValue: exercise.restSeconds, ExerciseRestPreference.key(for: exercise.id))
    }

    private var options: [Int] {
        Array(Set([0, 30, 60, 90, 120, 150, 180, 240, 300, seconds])).sorted()
    }

    var body: some View {
        HStack {
            Text("rest between sets").font(.caption).foregroundStyle(InkPalette.softInk)
            Spacer()
            Picker("Rest between sets", selection: $seconds) {
                ForEach(options, id: \.self) { value in
                    Text(value == 0 ? "Off" : String(format: "%d:%02d", value / 60, value % 60)).tag(value)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("\(exerciseName), rest between sets")
            .font(.caption.monospacedDigit())
            .tint(InkPalette.mineral)
            .frame(minHeight: 44)
        }
    }
}
