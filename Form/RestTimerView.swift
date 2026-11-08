import Foundation
import SwiftUI

struct RestTimer: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let end: Date
    var arrival = 0
    var compact = false
    var exerciseName = "Rest"
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(exerciseName).font(.caption).foregroundStyle(InkPalette.softInk)
                    Text(remaining == 0 ? "Ready" : String(format: "%d:%02d", remaining / 60, remaining % 60))
                        .font((compact ? Font.title3 : .title2).monospacedDigit())
                        .contentTransition(.numericText(countsDown: true))
                        .animation(reduceMotion ? nil : CounterweightMotion.quiet, value: remaining == 0)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(remaining == 0 ? "Rest complete" : "Rest remaining")
                .accessibilityValue(remaining == 0 ? "Ready" : "\(remaining / 60) minutes, \(remaining % 60) seconds")
                if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                HStack(spacing: 0) {
                    Button("−30s") { adjust(-30) }.accessibilityLabel("Subtract 30 seconds from rest")
                    Button("+30s") { adjust(30) }.accessibilityLabel("Add 30 seconds to rest")
                    Button(remaining == 0 ? "Done" : "Skip", action: cancel)
                        .accessibilityLabel(remaining == 0 ? "Dismiss rest timer" : "Skip rest")
                }.font(.caption).buttonStyle(RestNoteButtonStyle())
            }
            .padding(.horizontal, 12).padding(.vertical, compact ? 6 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(InkPalette.mist, in: RoundedRectangle(cornerRadius: 16))
            .onChange(of: remaining) { _, value in if value == 0 { complete() } }
        }
    }
}

private struct RestNoteButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(InkPalette.ink)
            .frame(minWidth: 44, minHeight: 44)
            .opacity(configuration.isPressed ? 0.65 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .animation(reduceMotion ? nil : CounterweightMotion.press, value: configuration.isPressed)
    }
}
