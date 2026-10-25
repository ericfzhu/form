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

struct SetLoggingRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let exerciseID: String
    let index: Int
    let measurement: ExerciseTemplate.Measurement
    @Binding var set: SetDraft
    @FocusState.Binding var focusedInput: WorkoutInputField?
    let canDelete: Bool
    let delete: () -> Void
    let didToggleCompletion: (Bool, SetKind) -> Void

    private var exerciseName: String { WorkoutCatalog.exercise(id: exerciseID)?.name ?? exerciseID }

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        layout {
            Menu {
                ForEach(SetKind.allCases) { kind in
                    Button {
                        set.kind = kind
                    } label: {
                        if set.kind == kind { Label(kind.title, systemImage: "checkmark") }
                        else { Text(kind.title) }
                    }
                }
                if canDelete {
                    Divider()
                    Button("Delete set", role: .destructive, action: delete)
                }
            } label: {
                HStack(spacing: 2) {
                    Text(set.kind == .warmup ? set.kind.shortTitle : "\(index)")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                }
                .font(.system(.body, design: .default, weight: .semibold))
                .foregroundStyle(set.kind == .warmup ? InkPalette.plum : InkPalette.softInk)
                .frame(minWidth: 40, minHeight: 44)
            }
            .tint(InkPalette.ink)
            .accessibilityLabel("\(exerciseName), set \(index), type: \(set.kind.title)")

            if measurement == .weighted || measurement == .weightedTimed {
                if typeSize.isAccessibilitySize { Text("Weight · kg").font(.caption) }
                TextField("0", value: $set.weight, format: .number.precision(.fractionLength(0...1)))
                    .accessibilityLabel("\(exerciseName), set \(index), weight in kilograms")
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .inkInput()
                    .focused($focusedInput, equals: WorkoutInputField(
                        exerciseID: exerciseID,
                        setID: set.id,
                        value: .load
                    ))
            } else {
                Text("body")
                    .font(.system(.caption, design: .default))
                    .foregroundStyle(InkPalette.softInk)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 42)
            }

            if typeSize.isAccessibilitySize {
                Text(measurement == .timed || measurement == .weightedTimed ? "Seconds" : "Repetitions").font(.caption)
            }
            TextField("0", value: $set.repetitions, format: .number)
                .accessibilityLabel("\(exerciseName), set \(index), \(measurement == .timed || measurement == .weightedTimed ? "seconds" : "repetitions")")
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .inkInput()
                .focused($focusedInput, equals: WorkoutInputField(
                    exerciseID: exerciseID,
                    setID: set.id,
                    value: .repetitions
                ))

            Button {
                set.completed.toggle()
                let completed = set.completed
                dismissKeyboard()
                didToggleCompletion(completed, set.kind)
            } label: {
                Label(set.completed ? "Completed" : "Complete set", systemImage: set.completed ? "checkmark.square.fill" : "square")
                    .labelStyle(SetCompletionLabelStyle(showTitle: typeSize.isAccessibilitySize))
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(set.completed ? InkPalette.ink : InkPalette.softInk.opacity(0.55))
                .frame(minWidth: 52, minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("\(exerciseName), set \(index), \(set.completed ? "mark incomplete" : "mark complete")")
        }
        .padding(.vertical, 2)
    }
}

struct InkInput: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body.monospacedDigit().weight(.medium))
            .foregroundStyle(InkPalette.ink)
            .frame(minHeight: 42)
            .overlay(alignment: .bottom) { InkDivider() }
    }
}

extension View {
    func inkInput() -> some View { modifier(InkInput()) }
}

private struct SetCompletionLabelStyle: LabelStyle {
    let showTitle: Bool
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.icon
            if showTitle { configuration.title.font(.body) }
        }
    }
}
