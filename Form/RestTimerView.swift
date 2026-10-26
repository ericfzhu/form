import Foundation
import SwiftUI

struct RestTimer: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let end: Date
    var arrival = 0
    var compact = false
    let adjust: (Int) -> Void
    let cancel: () -> Void
    let complete: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(end.timeIntervalSince(context.date).rounded(.up)))
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(spacing: 8))
            layout {
                HStack(spacing: 8) {
                    if !compact {
                        Image("paper-pause")
                            .resizable().scaledToFit()
                            .scaleEffect(1.4)
                            .frame(width: 72, height: 56)
                            .phaseAnimator([0.0, 1.0, 0.0], trigger: arrival) { figure, phase in
                                figure
                                    .rotationEffect(.degrees(reduceMotion ? 0 : -phase * 5), anchor: .bottom)
                                    .offset(y: reduceMotion ? 0 : -phase * 3)
                            } animation: { _ in .spring(response: 0.35, dampingFraction: 0.75) }
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(remaining == 0 ? "ready" : (compact || typeSize.isAccessibilitySize ? "rest" : "rest a little"))
                            .font(compact ? .caption : AtelierType.script(24))
                            .foregroundStyle(InkPalette.softInk)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                            .font((compact ? Font.title3 : .title2).monospacedDigit().weight(.medium))
                            .foregroundStyle(InkPalette.ink)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(remaining == 0 ? "Rest complete" : "Rest remaining")
                    .accessibilityValue(remaining == 0 ? "Ready when you are" : "\(remaining / 60) minute\(remaining / 60 == 1 ? "" : "s"), \(remaining % 60) second\(remaining % 60 == 1 ? "" : "s")")
                }
                if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                let controls = compact || typeSize.isAccessibilitySize
                    ? AnyLayout(HStackLayout(spacing: 12))
                    : AnyLayout(VStackLayout(spacing: 0))
                controls {
                    HStack(spacing: 8) {
                        Button("−30") { adjust(-30) }
                            .accessibilityLabel("Subtract 30 seconds")
                        Button("+30") { adjust(30) }
                            .accessibilityLabel("Add 30 seconds")
                    }
                    .font(.caption.monospacedDigit().weight(.medium))
                    Button(remaining == 0 ? "Done" : "Skip", action: cancel)
                        .font(compact ? .subheadline : AtelierType.script(22))
                        .accessibilityLabel(remaining == 0 ? "Dismiss rest timer" : "Skip rest")
                }
                .buttonStyle(RestNoteButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, compact ? 6 : 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(InkPalette.salvia.opacity(0.08))
            .onChange(of: remaining) { _, value in
                if value == 0 { complete() }
            }
        }
    }
}

private struct RestNoteButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(InkPalette.ink)
            .frame(minWidth: 44, minHeight: 44)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(InkPalette.salvia.opacity(configuration.isPressed ? 0.35 : 0))
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
