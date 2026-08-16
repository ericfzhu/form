import SwiftUI

enum TrendMetric: Hashable {
    case load
    case estimatedOneRepMax
    case repetitions
    case volume

    func title(for measurement: ExerciseTemplate.Measurement) -> String {
        switch self {
        case .load: "Load"
        case .estimatedOneRepMax: "1RM"
        case .repetitions:
            measurement == .timed || measurement == .weightedTimed ? "Time" : "Reps"
        case .volume: "Volume"
        }
    }

    func axisLabel(for measurement: ExerciseTemplate.Measurement) -> String {
        switch self {
        case .load: "Kilograms"
        case .estimatedOneRepMax: "Estimated 1RM"
        case .repetitions:
            measurement == .timed || measurement == .weightedTimed ? "Seconds" : "Repetitions"
        case .volume: "Kilograms"
        }
    }

    func value(for performance: ExercisePerformance) -> Double {
        switch self {
        case .load: performance.topSet?.weight ?? 0
        case .estimatedOneRepMax: performance.estimatedOneRepMax
        case .repetitions: Double(performance.bestRepetitions)
        case .volume: performance.totalVolume
        }
    }
}

struct EmptyExerciseRecord: View {
    let period: ProgressPeriod

    var body: some View {
        VStack(spacing: 12) {
            Text("No completed sets in \(period.title.lowercased())")
                .font(.system(.headline, design: .serif, weight: .semibold))
            Text("Choose another period or complete this movement to begin its record.")
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(InkPalette.softInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 38)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
