import SwiftUI

struct CardioLoggingSection: View {
    @Binding var entries: [CardioDraft]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("cardio")
                    .font(AtelierType.script(21))
                    .foregroundStyle(InkPalette.ink)
                Spacer()
                if !entries.isEmpty {
                    Text("\(Int(entries.reduce(0) { $0 + $1.durationMinutes })) MIN")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(InkPalette.softInk)
                }
            }

            ForEach($entries) { $entry in
                CardioEntryEditor(entry: $entry) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        entries.removeAll { $0.id == entry.id }
                    }
                }
            }

            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    entries.append(CardioDraft())
                }
            } label: {
                HStack(spacing: 8) {
                    Text(entries.isEmpty ? "Add cardio" : "Add another cardio entry")
                }
                .font(AtelierType.script(17))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .overlay(alignment: .top) { InkDivider() }
                .overlay(alignment: .bottom) { InkDivider() }
            }
            .buttonStyle(PressableButtonStyle())
        }
    }
}

struct CardioEntryEditor: View {
    @Binding var entry: CardioDraft
    let delete: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Picker("Cardio type", selection: $entry.kind) {
                    ForEach(CardioKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .tint(InkPalette.ink)
                .font(AtelierType.script(19))
                Spacer()
                Button(action: delete) {
                    Image(systemName: "trash")
                        .foregroundStyle(InkPalette.cinnabar)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Delete cardio entry")
            }

            HStack(spacing: 14) {
                cardioField("MINUTES", value: $entry.durationMinutes, placeholder: "30")
                cardioField("DISTANCE · KM", value: $entry.distanceKilometers, placeholder: "0")
            }
            HStack(spacing: 14) {
                cardioField("SPEED · KM/H", value: $entry.averageSpeed, placeholder: "0")
                if entry.kind.supportsIncline {
                    cardioField("INCLINE · %", value: $entry.incline, placeholder: "0")
                        .transition(.opacity)
                }
            }
        }
        .padding(.vertical, 10)
        .inkCard()
        .animation(.easeOut(duration: 0.18), value: entry.kind)
    }

    private func cardioField(
        _ label: String,
        value: Binding<Double>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .tracking(1)
                .foregroundStyle(InkPalette.softInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            TextField(
                placeholder,
                value: value,
                format: .number.precision(.fractionLength(0...2))
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.leading)
            .inkInput()
        }
        .frame(maxWidth: .infinity)
    }
}
