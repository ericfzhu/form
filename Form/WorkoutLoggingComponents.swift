import SwiftUI

struct ActiveWorkoutHeader: View {
    let index: String
    let progress: String
    let requestFinish: () -> Void
    let pause: () -> Void
    let requestDiscard: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            FormWordmark()
            Spacer(minLength: 0)
            Button("Pause and close", action: pause)
                .font(.subheadline).frame(minHeight: 44)
            Menu {
                Button("Finish workout", action: requestFinish)
                Button("Discard workout", role: .destructive, action: requestDiscard)
            } label: {
                Image(systemName: "ellipsis").frame(width: 44, height: 44)
            }.accessibilityLabel("Workout options")
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, 24).padding(.vertical, 6)
        .background(InkPalette.paper)
    }
}

struct ExerciseLoggingCard: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(NumberEntryForm.self) private var entryForm
    @State private var logPulse = 0
    @Binding var draft: ExerciseDraft
    let previous: ExercisePerformance?
    let recommendation: ProgressionRecommendation?
    let isExpanded: Bool
    let toggleExpanded: () -> Void
    let didUpdateSet: (UUID, Bool, SetKind) -> Void
    let didRemoveSet: (UUID) -> Void

    private var completedSetCount: Int { draft.sets.filter { $0.completed && $0.kind == .working }.count }
    private var workingSetCount: Int { draft.sets.filter { $0.kind == .working }.count }

    var body: some View {
        VStack(spacing: 0) {
            InkDivider()
            Button(action: toggleExpanded) {
                HStack(spacing: 14) {
                    DemonstrationImage(assetName: draft.template.assetName)
                        .frame(width: isExpanded ? 78 : 54, height: isExpanded ? 78 : 54)
                        .phaseAnimator([0.0, 1.0, 0.0], trigger: logPulse) { art, phase in
                            art.scaleEffect(x: reduceMotion ? 1 : 1 + phase * 0.035,
                                            y: reduceMotion ? 1 : 1 - phase * 0.035, anchor: .bottom)
                                .offset(y: reduceMotion ? 0 : -phase * 4)
                        } animation: { _ in CounterweightMotion.settle }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(draft.template.name).font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        if typeSize.isAccessibilitySize {
                            Text("\(completedSetCount)/\(workingSetCount) sets").font(.caption)
                        }
                    }
                    Spacer(minLength: 0)
                    if !typeSize.isAccessibilitySize {
                        Text("\(completedSetCount)/\(workingSetCount)").font(.caption.monospacedDigit())
                            .foregroundStyle(InkPalette.softInk)
                            .contentTransition(.numericText())
                    }
                    Image(systemName: "chevron.down").font(.caption)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .foregroundStyle(InkPalette.ink)
                .padding(.vertical, 14).contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(draft.template.name)
            .accessibilityValue("\(completedSetCount) of \(workingSetCount) working sets recorded. \(isExpanded ? "Expanded" : "Collapsed")")
            .accessibilityHint(isExpanded ? "Collapse set entry" : "Expand to log or correct sets")

            if isExpanded {
                VStack(spacing: 14) {
                    if let previous {
                        LastPerformanceSummary(template: draft.template, performance: previous, recommendation: recommendation)
                    }
                    Text(draft.template.targetText + (draft.id == "reverse-lunge" ? " per side" : ""))
                        .font(.caption).foregroundStyle(InkPalette.softInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !typeSize.isAccessibilitySize {
                        HStack {
                            Text("Set").frame(width: 40)
                            Text(draft.template.recordsLoad ? draft.template.loadLabel : "Load").frame(maxWidth: .infinity)
                            Text(draft.template.recordsTime ? "Sec" : "Reps").frame(maxWidth: .infinity)
                            Color.clear.frame(width: 52, height: 1)
                        }.font(.caption).foregroundStyle(InkPalette.softInk)
                    }
                    ForEach($draft.sets) { $set in
                        SetLoggingRow(exerciseID: draft.id, index: setNumber(for: set.id),
                                      measurement: draft.template.measurement, set: $set,
                                      canDelete: draft.sets.count > draft.template.sets || set.kind == .warmup,
                                      delete: {
                            let id = set.id
                            withAnimation(reduceMotion ? nil : CounterweightMotion.disclosure) {
                                draft.sets.removeAll { $0.id == id }
                                didRemoveSet(id)
                            }
                        }, didToggleCompletion: { completed, kind in
                            if completed { logPulse += 1 }
                            didUpdateSet(set.id, completed, kind)
                        })
                        .transition(CounterweightMotion.transition(reduced: reduceMotion))
                    }
                    HStack {
                        Button("Add set") { addSet(warmup: false) }.frame(minHeight: 44)
                        Spacer()
                        ExerciseRestPicker(exercise: draft.template)
                    }.font(.subheadline)
                    DisclosureGroup("Set options") {
                        VStack(alignment: .leading, spacing: 8) {
                            Button("Apply first set to remaining", action: applyFirstWorkingSetToRemaining)
                                .disabled(!canApplyFirstWorkingSet).frame(minHeight: 44)
                            Button("Add warm-up set") { addSet(warmup: true) }.frame(minHeight: 44)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.font(.subheadline)
                    DisclosureGroup("Movement notes") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Leave about 2 reps in reserve.")
                            ForEach(draft.template.formCues, id: \.self) { Text($0) }
                            if draft.id == "reverse-lunge" { Text("Record repetitions per side.") }
                        }.font(.subheadline).padding(.vertical, 10)
                    }.font(.subheadline)
                }
                .padding(.bottom, 24)
                .transition(CounterweightMotion.transition(reduced: reduceMotion))
            }
        }
        .animation(reduceMotion ? nil : CounterweightMotion.disclosure, value: isExpanded)
        .animation(reduceMotion ? nil : CounterweightMotion.quiet, value: completedSetCount)
    }

    private func setNumber(for id: UUID) -> Int {
        guard let index = draft.sets.firstIndex(where: { $0.id == id }) else { return 1 }
        let kind = draft.sets[index].kind
        return draft.sets.prefix(index + 1).filter { $0.kind == kind }.count
    }

    private func addSet(warmup: Bool) {
        let reference = draft.sets.last
        let set = SetDraft(weight: reference?.weight ?? 0,
                           repetitions: reference?.repetitions ?? draft.template.minimumRepetitions,
                           kind: warmup ? .warmup : .working)
        withAnimation(reduceMotion ? nil : CounterweightMotion.disclosure) {
            if warmup { draft.sets.insert(set, at: draft.sets.firstIndex { $0.kind == .working } ?? 0) }
            else { draft.sets.append(set) }
        }
    }

    private var canApplyFirstWorkingSet: Bool {
        guard let first = draft.sets.firstIndex(where: { $0.kind == .working }) else { return false }
        return draft.sets.indices.contains { $0 > first && draft.sets[$0].kind == .working && !draft.sets[$0].completed }
    }

    private func applyFirstWorkingSetToRemaining() {
        guard let first = draft.sets.firstIndex(where: { $0.kind == .working }) else { return }
        let reference = draft.sets[first]
        guard entryForm.validate(ids: [EntryID.load(reference.id), EntryID.count(reference.id)]) else { return }
        for index in draft.sets.indices where index > first && draft.sets[index].kind == .working && !draft.sets[index].completed {
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
    private var options: [Int] { Array(Set([0, 30, 60, 90, 120, 150, 180, 240, 300, seconds])).sorted() }
    var body: some View {
        HStack(spacing: 4) {
            Text("Rest").font(.caption).foregroundStyle(InkPalette.softInk)
            Picker("Rest", selection: $seconds) {
                ForEach(options, id: \.self) { value in
                    Text(value == 0 ? "Off" : String(format: "%d:%02d", value / 60, value % 60)).tag(value)
                }
            }.pickerStyle(.menu).accessibilityLabel("\(exerciseName), rest between sets")
                .font(.caption.monospacedDigit()).tint(InkPalette.ink).frame(minHeight: 44)
        }
    }
}
