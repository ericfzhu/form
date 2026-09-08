import SwiftUI

struct CardioLoggingSection: View {
    @EnvironmentObject private var planner: PlannerStore
    var prescribedWalk = false
    private var availableKinds: [CardioKind] {
        if prescribedWalk { return [.treadmillWalk] }
        return CardioKind.allCases.filter { kind in
            switch kind {
            case .treadmillWalk, .treadmillRun: planner.profile.equipment.contains(.treadmill)
            case .cycling: planner.profile.equipment.contains(.bike)
            case .elliptical: planner.profile.equipment.contains(.elliptical)
            case .rowing: planner.profile.equipment.contains(.rower)
            case .other: true
            }
        }
    }
    @Binding var entries: [CardioDraft]
    var timedWalk: TimedWalk? = nil
    var startWalk: (() -> Void)? = nil
    var finishWalk: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !prescribedWalk {
            HStack {
                Text("cardio")
                    .font(.system(.body, design: .default))
                    .foregroundStyle(InkPalette.ink)
                Spacer()
                if !entries.isEmpty {
                    Text("\(Int(entries.reduce(0) { $0 + $1.durationMinutes })) MIN")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(InkPalette.softInk)
                }
            }

            }

            if let startWalk, availableKinds.contains(.treadmillWalk) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Treadmill walk").font(.subheadline)
                        if let startedAt = timedWalk?.timerStartedAt {
                            Text(startedAt, style: .timer).monospacedDigit()
                        } else {
                            Text("15 min suggested").font(.caption).foregroundStyle(InkPalette.softInk)
                        }
                    }
                    Spacer()
                    Button(timedWalk == nil ? "Start walk" : "Finish walk") {
                        if timedWalk == nil { startWalk() } else { finishWalk?() }
                    }
                    .frame(minHeight: 44)
                }
                .padding(.horizontal, 12)
            }

            ForEach($entries) { $entry in
                CardioEntryEditor(entry: $entry, availableKinds: availableKinds) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        entries.removeAll { $0.id == entry.id }
                    }
                }
            }

            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    entries.append(CardioDraft(kind: availableKinds.first ?? .other, durationMinutes: 0, averageSpeed: 0, incline: 0))
                }
            } label: {
                HStack(spacing: 8) {
                    Text(entries.isEmpty ? (prescribedWalk ? "Record a walk already done" : "Add cardio") : "Add another cardio entry")
                }
                .font(AtelierType.script(17))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }
}

struct CardioEntryEditor: View {
    @Binding var entry: CardioDraft
    var availableKinds: [CardioKind] = CardioKind.allCases
    let delete: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Picker("Cardio type", selection: $entry.kind) {
                    ForEach(CardioKind.allCases.filter { availableKinds.contains($0) || $0 == entry.kind }) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .tint(InkPalette.ink)
                .font(.system(.body, design: .default))
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
