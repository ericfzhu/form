import SwiftUI
import SwiftData
import Charts

struct PerformanceSetValue: Hashable {
    let weight: Double
    let repetitions: Int
}

struct ExercisePerformance: Identifiable, Hashable {
    let id: PersistentIdentifier
    let date: Date
    let sets: [PerformanceSetValue]

    var topSet: PerformanceSetValue? {
        sets.max {
            if $0.weight == $1.weight {
                return $0.repetitions < $1.repetitions
            }
            return $0.weight < $1.weight
        }
    }

    var bestRepetitions: Int {
        sets.map(\.repetitions).max() ?? 0
    }

    var totalVolume: Double {
        sets.reduce(0) { $0 + $1.weight * Double($1.repetitions) }
    }

    var estimatedOneRepMax: Double {
        sets
            .filter { $0.weight > 0 && $0.repetitions > 0 }
            .map { $0.weight * (1 + Double($0.repetitions) / 30) }
            .max() ?? 0
    }
}

enum ProgressRecord: String, Identifiable {
    case load
    case estimatedOneRepMax
    case volume
    case repetitions

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .load: "LOAD PR"
        case .estimatedOneRepMax: "1RM PR"
        case .volume: "VOLUME PR"
        case .repetitions: "REP PR"
        }
    }
}

enum ProgressionEngine {
    static let loadIncrement = 2.5

    static func performances(
        for exerciseName: String,
        in workouts: [WorkoutRecord]
    ) -> [ExercisePerformance] {
        workouts.compactMap { workout in
            guard let exercise = workout.exercises.first(where: { $0.name == exerciseName }),
                  !exercise.sets.isEmpty else { return nil }

            let sets = exercise.sets
                .sorted { $0.order < $1.order }
                .map { PerformanceSetValue(weight: $0.weight, repetitions: $0.repetitions) }

            return ExercisePerformance(id: workout.persistentModelID, date: workout.date, sets: sets)
        }
        .sorted { $0.date > $1.date }
    }

    static func latestCompleted(
        for exerciseName: String,
        in workouts: [WorkoutRecord]
    ) -> ExercisePerformance? {
        performances(for: exerciseName, in: workouts).first
    }

    static func recommendedLoad(
        for template: ExerciseTemplate,
        after performance: ExercisePerformance?
    ) -> Double? {
        guard template.measurement == .weighted,
              let performance,
              performance.sets.count >= template.sets else { return nil }

        let prescribedSets = performance.sets.prefix(template.sets)
        guard prescribedSets.allSatisfy({
            $0.weight > 0 && $0.repetitions >= template.maximumRepetitions
        }), let currentLoad = prescribedSets.map(\.weight).max() else { return nil }

        return currentLoad + loadIncrement
    }

    static func personalRecords(
        for performance: ExercisePerformance,
        measurement: ExerciseTemplate.Measurement,
        among performances: [ExercisePerformance]
    ) -> [ProgressRecord] {
        let previous = performances.filter { $0.date < performance.date }
        guard !previous.isEmpty else { return [] }

        switch measurement {
        case .weighted:
            var records: [ProgressRecord] = []
            let previousLoad = previous.compactMap { $0.topSet?.weight }.max() ?? 0
            let currentLoad = performance.topSet?.weight ?? 0
            if currentLoad > previousLoad {
                records.append(.load)
            }
            if performance.estimatedOneRepMax > (previous.map(\.estimatedOneRepMax).max() ?? 0) {
                records.append(.estimatedOneRepMax)
            }
            if performance.totalVolume > (previous.map(\.totalVolume).max() ?? 0) {
                records.append(.volume)
            }
            return records
        case .bodyweight, .timed:
            let previousBest = previous.map(\.bestRepetitions).max() ?? 0
            return performance.bestRepetitions > previousBest ? [.repetitions] : []
        }
    }
}

struct ExerciseProgressView: View {
    let exercise: ExerciseTemplate

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]
    @State private var selectedMetric: TrendMetric = .load

    private var performances: [ExercisePerformance] {
        ProgressionEngine.performances(for: exercise.name, in: workouts)
    }

    private var availableMetrics: [TrendMetric] {
        switch exercise.measurement {
        case .weighted: [.load, .estimatedOneRepMax, .repetitions, .volume]
        case .bodyweight, .timed: [.repetitions]
        }
    }

    var body: some View {
        ZStack {
            PaperBackground()

            if performances.isEmpty {
                EmptyExerciseProgress(exercise: exercise)
            } else {
                ScrollView {
                    LazyVStack(spacing: 18) {
                        summary
                        trendChart
                        sessionHistory
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 30)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background {
            InteractivePopGestureBridge(isEnabled: true)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            progressHeader
        }
        .onAppear {
            if !availableMetrics.contains(selectedMetric) {
                selectedMetric = .repetitions
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 0) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(InkPalette.ink)
                        .frame(width: 40, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Back")

                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(InkPalette.cinnabar)
                        .frame(width: 9, height: 9)
                    Text(exercise.name.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(1.8)
                        .foregroundStyle(InkPalette.softInk)
                        .lineLimit(1)
                }
            }

            InkDivider()
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 6)
        .background(InkPalette.paper.opacity(0.96))
    }

    private var summary: some View {
        HStack(spacing: 0) {
            summaryItem(label: "SESSIONS", value: "\(performances.count)")
            summaryItem(label: "BEST", value: bestSummary)
            if exercise.measurement == .weighted {
                summaryItem(label: "EST. 1RM", value: bestOneRepMax)
            } else {
                summaryItem(label: "LATEST", value: shortDate(performances[0].date))
            }
        }
        .padding(.vertical, 14)
        .background(InkPalette.raisedPaper.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func summaryItem(label: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .tracking(1.3)
                .foregroundStyle(InkPalette.softInk)
            Text(value)
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(InkPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ForEach(availableMetrics, id: \.self) { metric in
                    Button {
                        selectedMetric = metric
                    } label: {
                        Text(metric.title(for: exercise.measurement))
                            .font(.system(.caption, design: .serif, weight: selectedMetric == metric ? .semibold : .regular))
                            .foregroundStyle(selectedMetric == metric ? InkPalette.ink : InkPalette.softInk)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 40)
                            .background {
                                if selectedMetric == metric {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(InkPalette.raisedPaper)
                                }
                            }
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }

            Chart(performances.reversed()) { performance in
                LineMark(
                    x: .value("Date", performance.date),
                    y: .value(selectedMetric.axisLabel(for: exercise.measurement), selectedMetric.value(for: performance))
                )
                .foregroundStyle(InkPalette.ink)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("Date", performance.date),
                    y: .value(selectedMetric.axisLabel(for: exercise.measurement), selectedMetric.value(for: performance))
                )
                .foregroundStyle(InkPalette.cinnabar)
                .symbolSize(34)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(InkPalette.softInk)
                    AxisTick().foregroundStyle(InkPalette.washedInk)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(InkPalette.washedInk.opacity(0.55))
                    AxisValueLabel().foregroundStyle(InkPalette.softInk)
                }
            }
            .frame(height: 220)
            .animation(.easeOut(duration: 0.2), value: selectedMetric)
        }
    }

    private var sessionHistory: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SESSIONS")
                .font(.caption2.weight(.semibold))
                .tracking(1.8)
                .foregroundStyle(InkPalette.softInk)
                .padding(.bottom, 8)

            ForEach(performances) { performance in
                HStack(spacing: 14) {
                    Text(shortDate(performance.date))
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(InkPalette.softInk)
                        .frame(width: 64, alignment: .leading)

                    Text(sessionSummary(performance))
                        .font(.subheadline.monospacedDigit().weight(.medium))
                        .foregroundStyle(InkPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer(minLength: 0)

                    if !records(for: performance).isEmpty {
                        Text("PR")
                            .font(.caption2.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(InkPalette.cinnabar)
                    }
                }
                .frame(minHeight: 48)

                if performance.id != performances.last?.id {
                    InkDivider()
                }
            }
        }
    }

    private var bestSummary: String {
        switch exercise.measurement {
        case .weighted:
            let best = performances.compactMap(\.topSet).max {
                if $0.weight == $1.weight { return $0.repetitions < $1.repetitions }
                return $0.weight < $1.weight
            }
            guard let best else { return "—" }
            return "\(weightText(best.weight)) × \(best.repetitions)"
        case .bodyweight:
            return "\(performances.map(\.bestRepetitions).max() ?? 0) reps"
        case .timed:
            return "\(performances.map(\.bestRepetitions).max() ?? 0) sec"
        }
    }

    private var bestOneRepMax: String {
        let value = performances.map(\.estimatedOneRepMax).max() ?? 0
        return "\(weightText(value)) kg"
    }

    private func records(for performance: ExercisePerformance) -> [ProgressRecord] {
        ProgressionEngine.personalRecords(
            for: performance,
            measurement: exercise.measurement,
            among: performances
        )
    }

    private func sessionSummary(_ performance: ExercisePerformance) -> String {
        switch exercise.measurement {
        case .weighted:
            guard let topSet = performance.topSet else { return "—" }
            return "\(weightText(topSet.weight)) kg × \(topSet.repetitions)  ·  \(Int(performance.totalVolume)) kg"
        case .bodyweight:
            return "Best \(performance.bestRepetitions) reps"
        case .timed:
            return "Best \(performance.bestRepetitions) sec"
        }
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    private func weightText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(value.rounded() == value ? 0 : 1)))
    }
}

private enum TrendMetric: Hashable {
    case load
    case estimatedOneRepMax
    case repetitions
    case volume

    func title(for measurement: ExerciseTemplate.Measurement) -> String {
        switch self {
        case .load: "Load"
        case .estimatedOneRepMax: "1RM"
        case .repetitions: measurement == .timed ? "Time" : "Reps"
        case .volume: "Volume"
        }
    }

    func axisLabel(for measurement: ExerciseTemplate.Measurement) -> String {
        switch self {
        case .load: "Kilograms"
        case .estimatedOneRepMax: "Estimated 1RM"
        case .repetitions: measurement == .timed ? "Seconds" : "Repetitions"
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

private struct EmptyExerciseProgress: View {
    let exercise: ExerciseTemplate

    var body: some View {
        VStack(spacing: 16) {
            DemonstrationImage(assetName: exercise.assetName, outlined: false)
                .frame(width: 210, height: 170)
            Text("No completed sets yet")
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(InkPalette.ink)
            Text("Complete this movement in a session to begin its record.")
                .font(.system(.body, design: .serif))
                .foregroundStyle(InkPalette.softInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 38)
        }
        .padding(.bottom, 48)
    }
}
