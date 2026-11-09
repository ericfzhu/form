import SwiftUI

struct CardioLoggingSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                    CounterweightControl(title: timedWalk == nil ? "Start walk" : "Finish walk", symbol: timedWalk == nil ? "play" : "checkmark") {
                        if timedWalk == nil { startWalk() } else { finishWalk?() }
                    }
                    .frame(minHeight: 44)
                }
                .padding(.horizontal, 12)
            }

            ForEach($entries) { $entry in
                CardioEntryEditor(entry: $entry, availableKinds: availableKinds) {
                    withAnimation(reduceMotion ? nil : CounterweightMotion.disclosure) {
                        entries.removeAll { $0.id == entry.id }
                    }
                }
            }

            CounterweightControl(title: entries.isEmpty ? (prescribedWalk ? "Record a walk" : "Cardio") : "Cardio", symbol: "plus") {
                withAnimation(reduceMotion ? nil : CounterweightMotion.disclosure) {
                    entries.append(CardioDraft(kind: availableKinds.first ?? .other, durationMinutes: 0, averageSpeed: 0, incline: 0))
                }
            }
            .accessibilityLabel(prescribedWalk ? "Record a walk already done" : "Add cardio")
        }
    }
}

struct CardioEntryEditor: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showingKinds = false
    @Binding var entry: CardioDraft
    var availableKinds: [CardioKind] = CardioKind.allCases
    let delete: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            let headerLayout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
            headerLayout {
                CounterweightControl(title: entry.kind.title, symbol: "chevron.down") {
                    dismissKeyboard()
                    showingKinds = true
                }
                .accessibilityLabel("Cardio type")
                .accessibilityValue(entry.kind.title)
                if !typeSize.isAccessibilitySize { Spacer() }
                CounterweightIconButton(symbol: "minus", label: "Remove \(entry.kind.title) entry", action: delete)
            }

            Text(entry.kind.supportsIncline ? "Distance, speed and incline are optional." : "Distance and speed are optional.")
                .font(.caption)
                .foregroundStyle(InkPalette.softInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            let fieldLayout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 14)) : AnyLayout(HStackLayout(spacing: 14))
            fieldLayout {
                cardioField("MINUTES", field: "minutes", value: $entry.durationMinutes)
                cardioField("DISTANCE · KM", field: "distance", value: $entry.distanceKilometers)
            }
            fieldLayout {
                cardioField("SPEED · KM/H", field: "speed", value: $entry.averageSpeed)
                if entry.kind.supportsIncline {
                    cardioField("INCLINE · %", field: "incline", value: $entry.incline)
                        .transition(.identity)
                }
            }
        }
        .padding(.vertical, 10)
        .inkCard()
        .animation(reduceMotion ? nil : CounterweightMotion.expand, value: entry.kind)
        .sheet(isPresented: $showingKinds) {
            CounterweightSheet(title: "Cardio type") {
                ForEach(CardioKind.allCases.filter { availableKinds.contains($0) || $0 == entry.kind }) { kind in
                    CounterweightChoice(title: kind.title, selected: entry.kind == kind) {
                        entry.kind = kind
                        showingKinds = false
                    }
                }
            }
        }
    }

    private func cardioField(
        _ label: String,
        field: String,
        value: Binding<Double>
    ) -> some View {
        NumberEntryField(id: EntryID.cardio(entry.id, field), label: entry.numberFields.first { $0.id == EntryID.cardio(entry.id, field) }?.label ?? label, value: value, caption: label)
    }
}
