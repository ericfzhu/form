import Foundation
import SwiftData
import SwiftUI

struct EmptyHistoryView: View {
    let showRestore: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            DemonstrationImage(assetName: "pages", outlined: false)
                .frame(width: 230, height: 180)
            Text("little by little.")
                .font(AtelierType.script(38))
            Text("Completed sessions will appear here.")
                .font(.system(.body, design: .default))
                .foregroundStyle(InkPalette.softInk)
            Button("Restore a backup", action: showRestore)
                .font(.system(.subheadline, design: .default, weight: .semibold))
                .foregroundStyle(InkPalette.cinnabar)
                .frame(minHeight: 44)
        }
        .padding(.bottom, 54)
    }
}

struct HistoryCard: View {
    let workout: WorkoutRecord

    var body: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text(workout.date.formatted(.dateTime.day())).font(.system(size: 28, weight: .light))
                Text(workout.date.formatted(.dateTime.month(.abbreviated))).font(.caption2)
            }.frame(width: 40)
            VStack(alignment: .leading, spacing: 7) {
                Text(workout.displayName).font(.body)
                Text(detailText).font(.caption).foregroundStyle(InkPalette.softInk)
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(InkPalette.softInk)
        }.foregroundStyle(InkPalette.ink)
            .padding(.vertical, 22)
            .overlay(alignment: .bottom) { InkDivider() }
            .contentShape(Rectangle())
    }

    private var detailText: String {
        var parts = [
            WorkoutValueFormatter.durationMinutes(workout.duration),
            "\(workout.exercises.filter { $0.sets.contains { $0.kind == .working } }.count) movements"
        ]
        let cardioMinutes = Int(workout.cardioEntries.reduce(0) { $0 + $1.durationMinutes })
        if cardioMinutes > 0 { parts.append("\(cardioMinutes)m cardio") }
        return parts.joined(separator: " · ")
    }
}

struct HistoryWeeklySummary: View {
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
            HStack(spacing: 0) {
                metric("\(weeklyWorkouts.count)", "SESSIONS")
                metric("\(minutes)", "MINUTES")
                metric("\(sets)", "SETS")
            }
            HStack {
                Text("Your rhythm · \(planner.profile.sessionsPerWeek) / week")
                Spacer()
                Text("\(prCount) PR\(prCount == 1 ? "" : "s")")
            }
            .font(.system(.caption, design: .default, weight: .semibold))
            .foregroundStyle(InkPalette.cinnabar)
            .monospacedDigit()
        }
        .padding(.horizontal, 7)
        .padding(.bottom, 16)
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
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .default, weight: .semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(InkPalette.softInk)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RecordSectionHeading: View {
    let title: String
    var detail: String = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(.body, design: .default))
                .foregroundStyle(InkPalette.ink)
            Spacer()
            if !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 9, weight: .medium, design: .default))
                    .foregroundStyle(InkPalette.softInk.opacity(0.72))
            }
        }
        .frame(minHeight: 38)
    }
}
