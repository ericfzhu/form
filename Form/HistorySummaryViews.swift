import Foundation
import SwiftData
import SwiftUI

struct EmptyHistoryView: View {
    let showRestore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DemonstrationImage(assetName: "pages", outlined: false)
                .frame(maxWidth: .infinity).frame(height: 180)
            Text("No sessions yet")
                .font(AtelierType.script(32))
                .accessibilityAddTraits(.isHeader)
            Text("Completed sessions will appear here.")
                .font(.system(.body, design: .default))
                .foregroundStyle(InkPalette.softInk)
            Button("Restore a backup", action: showRestore)
                .font(AtelierType.script(22))
                .foregroundStyle(InkPalette.cinnabar)
                .frame(minHeight: 44)
                .buttonStyle(PressableButtonStyle())
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)

    }
}

struct HistoryCard: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let workout: WorkoutRecord

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 20))
        layout {
            VStack(alignment: .leading, spacing: 7) {
                Text(workout.displayName).font(.headline)
                Text(workout.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(InkPalette.softInk)
                Text(SessionRecordSummary.text(for: workout)).font(.caption).foregroundStyle(InkPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !typeSize.isAccessibilitySize {
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(InkPalette.softInk)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(InkPalette.ink)
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) { InkDivider() }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(workout.date.formatted(date: .complete, time: .shortened)), \(workout.displayName), \(SessionRecordSummary.text(for: workout))")
    }
}

/// The same factual record line is used on Today and in History.
enum SessionRecordSummary {
    static func text(for workout: WorkoutRecord) -> String {
        let sets = workout.exercises.flatMap(\.sets)
        let working = sets.filter { $0.kind == .working }.count
        let warmups = sets.filter { $0.kind == .warmup }.count
        var parts = [workout.duration < 60 ? "<1 min" : WorkoutValueFormatter.durationMinutes(workout.duration)]
        if working > 0 { parts.append("\(working) working set\(working == 1 ? "" : "s")") }
        if warmups > 0 { parts.append("\(warmups) warm-up\(warmups == 1 ? "" : "s")") }
        let cardioMinutes = workout.cardioEntries.reduce(0) { $0 + $1.durationMinutes }
        if cardioMinutes > 0 { parts.append("\(WorkoutValueFormatter.decimal(cardioMinutes)) min cardio") }
        if sets.isEmpty && workout.cardioEntries.isEmpty { parts.append("No sets or cardio") }
        return parts.joined(separator: " · ")
    }
}

struct HistoryWeeklySummary: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @EnvironmentObject private var planner: PlannerStore
    let workouts: [WorkoutRecord]

    private var weeklyWorkouts: [WorkoutRecord] {
        workouts.filter {
            Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RecordSectionHeading(title: "This week")
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
            layout {
                metric("\(weeklyWorkouts.count)", "Sessions")
                metric("\(minutes)", "Minutes")
                metric("\(sets)", "Working sets")
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Weekly plan · \(planner.profile.sessionsPerWeek) sessions")
                if prCount > 0 { Text("\(prCount) personal record\(prCount == 1 ? "" : "s")") }
            }
            .font(.system(.caption, design: .default, weight: .semibold))
            .foregroundStyle(InkPalette.cinnabar)
            .monospacedDigit()
        }
        .padding(18)
        .background(InkPalette.salvia.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private var minutes: Int {
        weeklyWorkouts.reduce(0) { $0 + max(1, Int($1.duration / 60)) }
    }

    private var sets: Int {
        weeklyWorkouts.reduce(0) { total, workout in
            total + workout.exercises.reduce(0) {
                $0 + $1.sets.filter { $0.kind == .working }.count
            }
        }
    }

    private var prCount: Int {
        weeklyWorkouts.reduce(0) { total, workout in
            total + workout.exercises.reduce(0) { exerciseTotal, exercise in
                let performances = ProgressionEngine.performances(for: exercise, in: workouts)
                guard let performance = performances.first(where: {
                    $0.id == workout.persistentModelID
                }) else { return exerciseTotal }
                let measurement = WorkoutCatalog.exercise(for: exercise)?.measurement
                    ?? (exercise.sets.contains { $0.weight > 0 } ? .weighted : .bodyweight)
                return exerciseTotal + ProgressionEngine.personalRecords(
                    for: performance,
                    measurement: measurement,
                    among: performances
                ).count
            }
        }
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(AtelierType.script(30))
                .monospacedDigit()
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(InkPalette.softInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct RecordSectionHeading: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let title: String
    var detail: String = ""

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        return layout {
            Text(title)
                .font(AtelierType.script(26))
                .foregroundStyle(InkPalette.ink)
            if !typeSize.isAccessibilitySize { Spacer() }
            if !detail.isEmpty {
                Text(detail.lowercased())
                    .font(.caption2)
                    .foregroundStyle(InkPalette.softInk.opacity(0.72))
            }
        }
        .frame(minHeight: 38)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
