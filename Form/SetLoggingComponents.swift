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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var completionPulse = 0
    let exerciseID: String
    let index: Int
    let measurement: ExerciseTemplate.Measurement
    @Binding var set: SetDraft
    @Environment(NumberEntryForm.self) private var entryForm
    let canDelete: Bool
    let delete: () -> Void
    let didToggleCompletion: (Bool, SetKind) -> Void

    private var exerciseName: String { WorkoutCatalog.exercise(id: exerciseID)?.name ?? exerciseID }
    private var setDescription: String { self.set.kind == .warmup ? "warm-up set \(index)" : "set \(index)" }

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
            .accessibilityLabel("\(exerciseName), \(setDescription), type: \(set.kind.title)")

            if measurement == .weighted || measurement == .weightedTimed {
                if typeSize.isAccessibilitySize { Text("Weight · kg").font(.caption) }
                NumberEntryField(id: EntryID.load(set.id), label: "\(exerciseName), \(setDescription), weight in kilograms", value: $set.weight, alignment: .center)
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
            NumberEntryField(id: EntryID.count(set.id), label: "\(exerciseName), \(setDescription), \(measurement == .timed || measurement == .weightedTimed ? "seconds" : "repetitions")", value: Binding(get: { Double(set.repetitions) }, set: { set.repetitions = Int($0) }), whole: true, alignment: .center)

            Button {
                let ids = [EntryID.count(set.id)] + ((measurement == .weighted || measurement == .weightedTimed) ? [EntryID.load(set.id)] : [])
                guard set.completed || entryForm.validate(ids: ids) else { return }
                entryForm.done()
                set.completed.toggle()
                let completed = set.completed
                if completed { completionPulse += 1 }
                dismissKeyboard()
                didToggleCompletion(completed, set.kind)
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(set.completed ? InkPalette.salvia.opacity(0.35) : .clear)
                            .rotationEffect(.degrees(-6))
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(set.completed ? InkPalette.ink : InkPalette.softInk.opacity(0.55), lineWidth: 1.5)
                            .rotationEffect(.degrees(-6))
                        InkCheckStroke()
                            .trim(from: 0, to: set.completed ? 1 : 0)
                            .stroke(InkPalette.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .padding(7)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: set.completed)
                    }
                    .frame(width: 32, height: 32)
                    .phaseAnimator([0.0, 1.0, 0.0], trigger: completionPulse) { mark, phase in
                        mark.scaleEffect(reduceMotion ? 1 : 1 + phase * 0.16)
                    } animation: { _ in .spring(response: 0.22, dampingFraction: 0.6) }
                    if typeSize.isAccessibilitySize {
                        Text(set.completed ? "Completed" : "Complete set").font(.body)
                    }
                }
                .frame(minWidth: 52, minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .sensoryFeedback(.impact(weight: .medium, intensity: 0.65), trigger: completionPulse)
            .accessibilityLabel("\(exerciseName), \(setDescription), \(set.completed ? "mark incomplete" : "mark complete")")
            .accessibilityValue(set.completed ? "Completed" : "Not completed")
        }
        .padding(.vertical, 2)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(InkPalette.salvia.opacity(set.completed ? 0.12 : 0))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: set.completed)
        }
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

/// The slightly uneven stroke belongs to the same hand-drawn language as Form's tabs.
struct InkCheckStroke: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.36, y: rect.height * 0.85),
                          control: CGPoint(x: rect.width * 0.22, y: rect.height * 0.68))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.height * 0.1),
                          control: CGPoint(x: rect.width * 0.72, y: rect.height * 0.28))
        return path
    }
}
