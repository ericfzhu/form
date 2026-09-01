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
                .font(AtelierType.script(29))
            InkDivider().frame(width: 120)
            Text("Completed sessions will appear here.")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(InkPalette.softInk)
            Button("Restore a backup", action: showRestore)
                .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                .foregroundStyle(InkPalette.cinnabar)
                .frame(minHeight: 44)
        }
        .padding(.bottom, 54)
    }
}

struct HistoryCard: View {
    let workout: WorkoutRecord

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(workout.date.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.15)
                    .foregroundStyle(InkPalette.mineral)
                    .textCase(.uppercase)
                Text(workout.displayName)
                    .font(AtelierType.script(22))
                    .foregroundStyle(InkPalette.ink)
                Text(detailText)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(InkPalette.softInk.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                if workout.healthSyncStatus == .failed || workout.healthSyncStatus == .pending {
                    Text(workout.healthSyncStatus.title.uppercased())
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(InkPalette.cinnabar)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let assetName = workout.exercises.sorted(by: { $0.order < $1.order }).first?.assetName,
               !assetName.isEmpty {
                DemonstrationImage(assetName: assetName, outlined: false)
                    .frame(width: 78, height: 78)
                    .rotationEffect(.degrees(workout.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 2) - 0.5))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(InkPalette.softInk.opacity(0.55))
        }
        .padding(.leading, 7)
        .padding(.trailing, 3)
        .padding(.vertical, 10)
        .frame(minHeight: 106)
        .overlay(alignment: .bottom) { InkDivider().opacity(0.38) }
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
                Text("Next session · \(WorkoutCatalog.nextRoutine(after: workouts.first).id)")
                Spacer()
                Text("\(prCount) PR\(prCount == 1 ? "" : "s")")
            }
            .font(.system(.caption, design: .monospaced, weight: .semibold))
            .foregroundStyle(InkPalette.cinnabar)
            .monospacedDigit()
        }
        .padding(.horizontal, 7)
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) { InkDivider().opacity(0.38) }
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
                .font(.system(.title3, design: .monospaced, weight: .semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption2.weight(.semibold))
                .tracking(1)
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
                .font(AtelierType.script(22))
                .foregroundStyle(InkPalette.ink)
            Spacer()
            if !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(InkPalette.softInk.opacity(0.72))
            }
        }
        .frame(minHeight: 38)
        .overlay(alignment: .bottom) { InkDivider().opacity(0.38) }
    }
}
