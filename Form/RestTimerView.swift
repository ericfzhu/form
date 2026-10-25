import Foundation
import SwiftUI

struct RestTimer: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let end: Date
    let adjust: (Int) -> Void
    let cancel: () -> Void
    let complete: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(end.timeIntervalSince(context.date).rounded(.up)))
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())
            layout {
                let summaryLayout = typeSize.isAccessibilitySize ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                summaryLayout {
                    Text(remaining == 0 ? "Ready" : "Rest")
                        .font(.caption2)
                        .foregroundStyle(InkPalette.softInk)
                    Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                        .font(.title3.monospacedDigit().weight(.semibold))
                }
                if !typeSize.isAccessibilitySize { Spacer() }
                HStack(spacing: 16) {
                Button("−30") { adjust(-30) }
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Subtract 30 seconds")
                Button("+30") { adjust(30) }
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Add 30 seconds")
                Button(remaining == 0 ? "Dismiss" : "Skip", action: cancel)
                    .font(typeSize.isAccessibilitySize ? .caption2 : .subheadline)
                    .lineLimit(1)
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: 64)
            .onChange(of: remaining) { _, value in
                if value == 0 { complete() }
            }
        }
    }
}
