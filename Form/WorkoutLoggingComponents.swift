import SwiftUI

struct ActiveWorkoutHeader: View {
    let pause: () -> Void
    let showOptions: () -> Void

    var body: some View {
        CounterweightHeader {
            CounterweightControl(title: "Pause", symbol: "pause", action: pause)
                .accessibilityLabel("Pause and close")
                .accessibilityHint("Saves this session so you can resume it from Today")
            CounterweightIconButton(symbol: "ellipsis", label: "Workout options", action: showOptions)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct ExerciseLoggingCard: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(NumberEntryForm.self) private var entryForm
    @ScaledMetric(relativeTo: .subheadline) private var setMarkSize = 48
    @Namespace private var selectionMark
    @State private var logPulse = 0
    @State private var showingTechnique = false
    @Binding var draft: ExerciseDraft
    @Binding var selectedSetID: UUID?
    let previous: ExercisePerformance?
    let recommendation: ProgressionRecommendation?
    let isExpanded: Bool
    let toggleExpanded: () -> Void
    let didUpdateSet: (UUID, Bool, SetKind) -> Void
    let didRemoveSet: (UUID) -> Void

    private var completedSetCount: Int { draft.sets.filter { $0.completed && $0.kind == .working }.count }
    private var workingSetCount: Int { draft.sets.filter { $0.kind == .working }.count }
    private var selectedIndex: Int? { draft.sets.firstIndex { $0.id == selectedSetID } }

    var body: some View {
        VStack(spacing: 0) {
            InkDivider()
            HStack(spacing: 4) {
                Button(action: toggleExpanded) {
                    let headerLayout = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
                        : AnyLayout(HStackLayout(spacing: 14))
                    headerLayout {
                        DemonstrationImage(assetName: draft.template.assetName)
                            .frame(width: 64, height: 64)
                            .phaseAnimator([0.0, 1.0, 0.0], trigger: logPulse) { art, phase in
                                art.scaleEffect(x: reduceMotion ? 1 : 1 + phase * 0.035,
                                                y: reduceMotion ? 1 : 1 - phase * 0.035, anchor: .bottom)
                                    .offset(y: reduceMotion ? 0 : -phase * 4)
                            } animation: { _ in CounterweightMotion.settle }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(draft.template.name).font(.headline).fixedSize(horizontal: false, vertical: true)
                            Text(isExpanded ? draft.template.targetText + (draft.id == "reverse-lunge" ? " / side" : "") : "\(completedSetCount)/\(workingSetCount) recorded")
                                .font(.caption).foregroundStyle(InkPalette.softInk)
                        }
                        if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(InkPalette.ink).padding(.vertical, 16).contentShape(Rectangle())
                }
                .accessibilityLabel(draft.template.name)
                .accessibilityValue("\(completedSetCount) of \(workingSetCount) working sets recorded. \(isExpanded ? "Expanded" : "Collapsed")")
                .accessibilityHint(isExpanded ? "Show all exercises" : "Open focused set controls")
                if isExpanded && !draft.template.formCues.isEmpty {
                    CounterweightIconButton(symbol: "info", label: "Technique for \(draft.template.name)") {
                        entryForm.done(); dismissKeyboard(); showingTechnique = true
                    }
                } else {
                    CounterweightIconButton(
                        symbol: isExpanded ? "chevron.up" : (completedSetCount == workingSetCount && workingSetCount > 0 ? "checkmark" : "chevron.down"),
                        label: "\(isExpanded ? "Close" : "Open") \(draft.template.name)", action: toggleExpanded
                    ).accessibilityHidden(true)
                }
            }
            .buttonStyle(PressableButtonStyle())
            CounterweightRevealLayout(amount: isExpanded ? 1 : 0) {
                VStack(alignment: .leading, spacing: 18) {
                    setMarks
                    if let index = selectedIndex {
                        FocusedSetControls(template: draft.template, index: setNumber(for: draft.sets[index].id),
                                           set: setBinding(draft.sets[index]),
                                           canDelete: draft.sets.count > 1,
                                           canCopy: canCopy(from: index),
                                           copy: { copyRemaining(from: index) },
                                           delete: { removeSet(at: index) },
                                           nextSet: nextUnrecorded(after: index).map { id in { select(id) } },
                                           showExercises: toggleExpanded,
                                           didToggleCompletion: { completed, kind in
                            if completed { logPulse += 1 }
                            didUpdateSet(draft.sets[index].id, completed, kind)
                        })
                        .id(draft.sets[index].id)
                        .transition(.identity)
                    }
                    let additionLayout = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                        : AnyLayout(HStackLayout(spacing: 20))
                    additionLayout {
                        CounterweightControl(title: "Set", symbol: "plus") { addSet(warmup: false) }
                            .accessibilityLabel("Add working set")
                        CounterweightControl(title: "Warm-up", symbol: "plus") { addSet(warmup: true) }
                            .accessibilityLabel("Add warm-up set")
                    }
                    .font(.caption).buttonStyle(PressableButtonStyle()).frame(minHeight: 44)
                    if let previous {
                        LastPerformanceSummary(template: draft.template, performance: previous, recommendation: recommendation)
                    }
                }
                .padding(.bottom, 24)
            }
            .clipped()
            .allowsHitTesting(isExpanded)
            .accessibilityHidden(!isExpanded)
        }
        .animation(reduceMotion ? nil : CounterweightMotion.expand, value: isExpanded)
        .sheet(isPresented: $showingTechnique) { ExerciseTechniqueView(exercise: draft.template) }
    }

    private var setMarks: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(draft.sets) { set in
                        Button { select(set.id) } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    if selectedSetID == set.id {
                                        Circle().stroke(InkPalette.ink, lineWidth: 1.5)
                                            .matchedGeometryEffect(id: "selected-set", in: selectionMark)
                                    }
                                    Circle().fill(set.completed ? InkPalette.ink : InkPalette.mist).padding(4)
                                    Text(set.kind == .warmup ? "W\(setNumber(for: set.id))" : "\(setNumber(for: set.id))")
                                        .font(.subheadline.monospacedDigit().weight(.medium))
                                        .foregroundStyle(set.completed ? InkPalette.paper : InkPalette.ink)
                                }.frame(width: setMarkSize, height: setMarkSize)
                                HStack(spacing: 3) {
                                    if set.completed { Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)) }
                                    Text(set.completed ? shortResult(set) : "—")
                                        .font(.caption2.monospacedDigit())
                                }.foregroundStyle(InkPalette.softInk)
                            }.frame(width: typeSize.isAccessibilitySize ? 144 : 88).contentShape(Rectangle())
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityLabel("\(draft.template.name), \(set.kind == .warmup ? "warm-up" : "set") \(setNumber(for: set.id))")
                        .accessibilityValue(set.completed ? "Recorded, " + shortResult(set) : "Unrecorded")
                        .accessibilityAddTraits(selectedSetID == set.id ? .isSelected : [])
                        .id(set.id)
                    }
                }.padding(.vertical, 3).padding(.horizontal, 2)
            }
            .task(id: selectedSetID) {
                await Task.yield()
                guard let id = selectedSetID else { return }
                withAnimation(reduceMotion ? nil : CounterweightMotion.quiet) { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    private func shortResult(_ set: SetDraft) -> String {
        WorkoutValueFormatter.setText(weight: set.weight, repetitions: set.repetitions, template: draft.template)
    }

    // Outgoing editor views can remain alive during their removal transition.
    private func setBinding(_ set: SetDraft) -> Binding<SetDraft> {
        Binding(get: { draft.sets.first(where: { $0.id == set.id }) ?? set }, set: { updated in
            if let index = draft.sets.firstIndex(where: { $0.id == set.id }) { draft.sets[index] = updated }
        })
    }

    private func setNumber(for id: UUID) -> Int {
        guard let index = draft.sets.firstIndex(where: { $0.id == id }) else { return 1 }
        return draft.sets.prefix(index + 1).filter { $0.kind == draft.sets[index].kind }.count
    }

    private func select(_ id: UUID) {
        entryForm.done(); dismissKeyboard()
        withAnimation(reduceMotion ? nil : CounterweightMotion.quiet) { selectedSetID = id }
    }

    private func nextUnrecorded(after index: Int) -> UUID? {
        let order = Array(draft.sets.indices.dropFirst(index + 1)) + Array(draft.sets.indices.prefix(index))
        return order.first(where: { !draft.sets[$0].completed }).map { draft.sets[$0].id }
    }

    private func addSet(warmup: Bool) {
        entryForm.done(); dismissKeyboard()
        let reference = selectedIndex.map { draft.sets[$0] } ?? draft.sets.last
        let set = SetDraft(weight: reference?.weight ?? 0,
                           repetitions: reference?.repetitions ?? draft.template.minimumRepetitions,
                           kind: warmup ? .warmup : .working)
        withAnimation(reduceMotion ? nil : CounterweightMotion.disclosure) {
            if warmup { draft.sets.insert(set, at: draft.sets.firstIndex { $0.kind == .working } ?? 0) }
            else { draft.sets.append(set) }
            selectedSetID = set.id
        }
    }

    private func removeSet(at index: Int) {
        entryForm.done(); dismissKeyboard()
        let id = draft.sets[index].id
        withAnimation(reduceMotion ? nil : CounterweightMotion.disclosure) {
            draft.sets.remove(at: index)
            selectedSetID = draft.sets[min(index, draft.sets.count - 1)].id
            didRemoveSet(id)
        }
    }

    private func canCopy(from index: Int) -> Bool {
        draft.sets.indices.contains { $0 > index && draft.sets[$0].kind == draft.sets[index].kind && !draft.sets[$0].completed }
    }

    private func copyRemaining(from index: Int) {
        let reference = draft.sets[index]
        let ids = [EntryID.count(reference.id)] + (draft.template.recordsLoad ? [EntryID.load(reference.id)] : [])
        guard entryForm.validate(ids: ids) else { return }
        for target in draft.sets.indices where target > index && draft.sets[target].kind == reference.kind && !draft.sets[target].completed {
            draft.sets[target].weight = reference.weight
            draft.sets[target].repetitions = reference.repetitions
            entryForm.replaceValue(reference.weight, id: EntryID.load(draft.sets[target].id))
            entryForm.replaceValue(Double(reference.repetitions), id: EntryID.count(draft.sets[target].id))
        }
    }
}

private struct ExerciseTechniqueView: View {
    let exercise: ExerciseTemplate
    var body: some View {
        CounterweightSheet(title: "Technique", subtitle: exercise.name) {
            DemonstrationImage(assetName: exercise.assetName)
                .frame(width: 112, height: 112).frame(maxWidth: .infinity)
            ForEach(exercise.formCues, id: \.self) { cue in
                Text(cue).font(.body).fixedSize(horizontal: false, vertical: true)
            }
            if exercise.id == "reverse-lunge" { Text("Record repetitions per side.").font(.subheadline) }
        }
    }
}

struct ExerciseRestPicker: View {
    @AppStorage private var seconds: Int
    @State private var showingOptions = false
    private let exerciseName: String
    init(exercise: ExerciseTemplate) {
        exerciseName = exercise.name
        _seconds = AppStorage(wrappedValue: exercise.restSeconds, ExerciseRestPreference.key(for: exercise.id))
    }
    private var options: [Int] { Array(Set([0, 30, 60, 90, 120, 150, 180, 240, 300, seconds])).sorted() }
    private func label(_ value: Int) -> String { value == 0 ? "Off" : String(format: "%d:%02d", value / 60, value % 60) }
    var body: some View {
        CounterweightControl(title: "Auto " + label(seconds), symbol: "timer") { showingOptions = true }
            .accessibilityLabel("\(exerciseName), automatic rest between sets")
            .accessibilityValue(label(seconds))
            .sheet(isPresented: $showingOptions) {
                CounterweightSheet(title: "Rest between sets", subtitle: exerciseName) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 88))], spacing: 12) {
                        ForEach(options, id: \.self) { value in
                            Button { seconds = value; showingOptions = false } label: {
                                Text(label(value)).font(.subheadline.monospacedDigit().weight(.medium))
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .foregroundStyle(seconds == value ? InkPalette.paper : InkPalette.ink)
                                    .background(seconds == value ? InkPalette.ink : InkPalette.mist, in: Capsule())
                            }.buttonStyle(PressableButtonStyle())
                                .accessibilityAddTraits(seconds == value ? .isSelected : [])
                        }
                    }
                }
            }
    }
}
