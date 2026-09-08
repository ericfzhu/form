import Foundation
import SwiftUI

struct RestTimer: View {
    let end: Date
    let adjust: (Int) -> Void
    let cancel: () -> Void
    let complete: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(end.timeIntervalSince(context.date).rounded(.up)))
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(remaining == 0 ? "ready when you are" : "rest")
                        .font(.system(.caption, design: .default))
                        .foregroundStyle(InkPalette.softInk)
                    Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                        .font(.title3.monospacedDigit().weight(.semibold))
                }
                Spacer()
                Button("−30") { adjust(-30) }
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Subtract 30 seconds")
                Button("+30") { adjust(30) }
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Add 30 seconds")
                Button(remaining == 0 ? "Continue" : "Skip", action: cancel)
                    .font(.system(.subheadline, design: .default))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, 16)
            .frame(height: 64)
            .onChange(of: remaining) { _, value in
                if value == 0 { complete() }
            }
        }
    }
}
