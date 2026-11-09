import SwiftUI

struct LastPerformanceSummary: View {
    let template: ExerciseTemplate
    let performance: ExercisePerformance
    let recommendation: ProgressionRecommendation?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("last · \(performance.date.formatted(.dateTime.day().month(.abbreviated)).lowercased())")
                    .font(.system(.caption2, design: .default))
                    .foregroundStyle(InkPalette.softInk)
                Spacer()
                if let recommendation {
                    Text(recommendation.title.lowercased())
                        .font(.system(.caption2, design: .default))
                        .foregroundStyle(InkPalette.cinnabar)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }
            Text(performance.sets.map {
                WorkoutValueFormatter.setText(
                    weight: $0.weight,
                    repetitions: $0.repetitions,
                    template: template
                )
            }.joined(separator: "  ·  "))
            .font(.caption.monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.72)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One editable set at a time. Logging settles this same workspace into a receipt;
/// selecting another mark or Next set is an explicit navigation action.
struct FocusedSetControls: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(NumberEntryForm.self) private var entryForm
    @State private var editingRecordedSet = false
    @State private var completionPulse = 0
    let template: ExerciseTemplate
    let index: Int
    @Binding var set: SetDraft
    let canDelete: Bool
    let canCopy: Bool
    let copy: () -> Void
    let delete: () -> Void
    let nextSet: (() -> Void)?
    let showExercises: () -> Void
    let didToggleCompletion: (Bool, SetKind) -> Void

    private var title: String { self.set.kind == .warmup ? "Warm-up \(index)" : "Set \(index)" }
    private var fieldIDs: [String] {
        (template.recordsLoad ? [EntryID.load(set.id)] : []) + [EntryID.count(set.id)]
    }
    private var isEditing: Bool {
        !set.completed || editingRecordedSet || fieldIDs.contains(entryForm.focusedID ?? "")
            || !entryForm.invalidIDs.isDisjoint(with: fieldIDs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title).font(.subheadline).accessibilityAddTraits(.isHeader)
                Spacer()
                Menu {
                    Button("Copy to remaining sets", action: copy).disabled(!canCopy)
                    ForEach(SetKind.allCases) { kind in
                        Button {
                            withAnimation(reduceMotion ? nil : CounterweightMotion.quiet) { set.kind = kind }
                        } label: {
                            if set.kind == kind { Label(kind.title, systemImage: "checkmark") }
                            else { Text(kind.title) }
                        }
                    }
                    if set.completed {
                        Button("Mark unrecorded") {
                            entryForm.done(); dismissKeyboard()
                            withAnimation(reduceMotion ? nil : CounterweightMotion.settle) {
                                set.completed = false
                                editingRecordedSet = false
                                didToggleCompletion(false, set.kind)
                            }
                        }
                    }
                    if canDelete { Button("Remove set", role: .destructive, action: delete) }
                } label: {
                    Image(systemName: "ellipsis").frame(width: 44, height: 44)
                }.accessibilityLabel("\(template.name), \(title), actions")
            }
            // Both entry and recorded states use the same footprint at standard text sizes.
            Group {
                if isEditing {
                    let layout = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(spacing: 16)) : AnyLayout(HStackLayout(spacing: 24))
                    layout {
                        if template.recordsLoad {
                            NumberEntryField(id: EntryID.load(set.id), label: "\(template.name), \(title), weight in kilograms",
                                             value: $set.weight, caption: "kg")
                        }
                        NumberEntryField(id: EntryID.count(set.id), label: "\(template.name), \(title), \(template.recordsTime ? "seconds" : "repetitions")",
                                         value: Binding(get: { Double(set.repetitions) }, set: { set.repetitions = Int($0) }),
                                         whole: true, caption: template.recordsTime ? "seconds" : "reps")
                    }
                    .transition(.opacity)
                } else {
                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(WorkoutValueFormatter.setText(weight: set.weight, repetitions: set.repetitions, template: template))
                                .font(.title3.monospacedDigit().weight(.medium))
                                .fixedSize(horizontal: false, vertical: true)
                            Label("Recorded", systemImage: "checkmark").font(.caption).foregroundStyle(InkPalette.softInk)
                        }
                        Spacer(minLength: 0)
                        Button("Edit") {
                            withAnimation(reduceMotion ? nil : CounterweightMotion.quiet) { editingRecordedSet = true }
                        }.font(.subheadline).frame(minWidth: 44, minHeight: 44)
                    }
                    .transition(CounterweightMotion.transition(reduced: reduceMotion))
                }
            }
            .frame(minHeight: typeSize.isAccessibilitySize ? 0 : 76, alignment: .center)
            Button(action: primaryAction) {
                HStack(spacing: 10) {
                    Text(isEditing ? (set.completed ? "Done" : "Log set") : (nextSet == nil ? "Exercises" : "Next set"))
                    Image(systemName: isEditing ? "checkmark" : "arrow.right")
                }
                .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(InkPalette.paper).background(InkPalette.ink, in: Capsule())
                .phaseAnimator([0.0, 1.0, 0.0], trigger: completionPulse) { mark, phase in
                    mark.scaleEffect(x: reduceMotion ? 1 : 1 + phase * 0.015,
                                     y: reduceMotion ? 1 : 1 - phase * 0.045)
                } animation: { _ in CounterweightMotion.press }
            }
            .accessibilityLabel(isEditing ? (set.completed ? "Finish editing \(title)" : "Log \(template.name), \(title)") : (nextSet == nil ? "Show exercises" : "Next unrecorded set"))
            .sensoryFeedback(.impact(weight: .medium, intensity: 0.65), trigger: completionPulse)
        }
        .buttonStyle(PressableButtonStyle())
        .animation(reduceMotion ? nil : CounterweightMotion.settle, value: set.completed)
    }

    private func primaryAction() {
        if isEditing {
            guard entryForm.validate(ids: fieldIDs) else { return }
            entryForm.done(); dismissKeyboard()
            withAnimation(reduceMotion ? nil : CounterweightMotion.settle) {
                editingRecordedSet = false
                if !set.completed {
                    set.completed = true
                    completionPulse += 1
                    didToggleCompletion(true, set.kind)
                }
            }
        } else if let nextSet { nextSet() }
        else { showExercises() }
    }
}

struct InkInput: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.title3.monospacedDigit())
            .foregroundStyle(InkPalette.ink)
            .frame(minHeight: 42)
            .overlay(alignment: .bottom) { InkDivider() }
    }
}

extension View {
    func inkInput() -> some View { modifier(InkInput()) }
}
