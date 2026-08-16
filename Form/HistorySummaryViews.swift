import Foundation
import SwiftData
import SwiftUI

struct EmptyHistoryView: View {
    let showRestore: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            DemonstrationImage(assetName: "plank", outlined: false)
                .frame(width: 230, height: 180)
                .mask(LinearGradient(
                    colors: [.clear, .black, .black, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
            Text("No sessions recorded")
                .font(.system(size: 30, weight: .semibold, design: .serif))
            InkDivider().frame(width: 120)
            Text("Completed sessions will appear here.")
                .font(.system(.body, design: .serif))
                .foregroundStyle(InkPalette.softInk)
            Button("Restore a backup", action: showRestore)
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(InkPalette.cinnabar)
                .frame(minHeight: 44)
        }
        .padding(.bottom, 54)
    }
}

struct HistoryCard: View {
    let workout: WorkoutRecord

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text(workout.date.formatted(.dateTime.day()))
                    .font(.system(size: 31, weight: .medium, design: .serif))
                Text(workout.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(1.4)
                    .foregroundStyle(InkPalette.softInk)
            }
            .frame(width: 62)
            Rectangle().fill(InkPalette.ink.opacity(0.18)).frame(width: 1, height: 58)
            VStack(alignment: .leading, spacing: 6) {
                Text(workout.displayName)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                Text(detailText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(InkPalette.softInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                if workout.healthSyncStatus == .failed || workout.healthSyncStatus == .pending {
                    Text(workout.healthSyncStatus.title.uppercased())
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(InkPalette.cinnabar)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(InkPalette.bronze.opacity(0.72))
        }
        .padding(16)
        .inkCard()
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
    let workouts: [WorkoutRecord]

    private var weeklyWorkouts: [WorkoutRecord] {
        workouts.filter {
            Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THIS WEEK")
                .font(.caption2.weight(.semibold))
                .tracking(1.8)
                .foregroundStyle(InkPalette.softInk)
            HStack(spacing: 0) {
                metric("\(weeklyWorkouts.count)", "SESSIONS")
                metric("\(minutes)", "MINUTES")
                metric("\(sets)", "SETS")
            }
            HStack {
                Text("Next session · \(WorkoutCatalog.nextRoutine(after: workouts.first).id)")
                Spacer()
                Text("\(prCount) PR\(prCount == 1 ? "" : "s")")
            }
            .font(.system(.caption, design: .serif, weight: .semibold))
            .foregroundStyle(InkPalette.cinnabar)
            .monospacedDigit()
        }
        .padding(15)
        .inkCard()
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
                .font(.system(.title3, design: .serif, weight: .semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption2.weight(.semibold))
                .tracking(1)
                .foregroundStyle(InkPalette.softInk)
        }
        .frame(maxWidth: .infinity)
    }
}

