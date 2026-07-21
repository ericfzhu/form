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

struct ProgressionRecommendation {
    let title: String
    let detail: String
}

enum ProgressionEngine {
    static var loadIncrement: Double {
        let stored = UserDefaults.standard.double(forKey: "progression-load-increment")
        return stored > 0 ? stored : 2.5
    }

    static func performances(
        for exerciseName: String,
        in workouts: [WorkoutRecord]
    ) -> [ExercisePerformance] {
        workouts.compactMap { workout in
            guard let exercise = workout.exercises.first(where: { $0.name == exerciseName }),
                  !exercise.sets.isEmpty else { return nil }

            let sets = exercise.sets
                .filter { $0.kind == .working }
                .sorted { $0.order < $1.order }
                .map { PerformanceSetValue(weight: $0.weight, repetitions: $0.repetitions) }

            guard !sets.isEmpty else { return nil }

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

    static func recommendation(
        for template: ExerciseTemplate,
        performances: [ExercisePerformance]
    ) -> ProgressionRecommendation? {
        guard let latest = performances.first else { return nil }

        switch template.measurement {
        case .weighted:
            let prescribed = Array(latest.sets.prefix(template.sets))
            guard !prescribed.isEmpty else { return nil }
            let currentLoad = prescribed.map(\.weight).max() ?? 0
            let load = currentLoad.formatted(.number.precision(.fractionLength(0...2)))

            if prescribed.count >= template.sets,
               prescribed.allSatisfy({ $0.repetitions >= template.maximumRepetitions }) {
                let next = (currentLoad + loadIncrement)
                    .formatted(.number.precision(.fractionLength(0...2)))
                return ProgressionRecommendation(
                    title: "Increase to \(next) kg\(template.usesPerHandLoad ? " / hand" : "")",
                    detail: "You reached the top of the target range across every prescribed set."
                )
            }

            let repeatedShortfall = performances.prefix(2).count == 2
                && performances.prefix(2).allSatisfy { performance in
                    let sets = Array(performance.sets.prefix(template.sets))
                    return sets.count < template.sets
                        || sets.contains { $0.repetitions < template.minimumRepetitions }
                }

            if repeatedShortfall, currentLoad > 0 {
                let reduced = max(0, currentLoad - loadIncrement)
                    .formatted(.number.precision(.fractionLength(0...2)))
                return ProgressionRecommendation(
                    title: "Consider \(reduced) kg\(template.usesPerHandLoad ? " / hand" : "")",
                    detail: "The minimum target was missed in two consecutive sessions."
                )
            }

            return ProgressionRecommendation(
                title: "Keep \(load) kg\(template.usesPerHandLoad ? " / hand" : "")",
                detail: "Aim to add one repetition while staying inside the target range."
            )
        case .bodyweight:
            return ProgressionRecommendation(
                title: "Add one repetition",
                detail: "Keep the same movement quality and build toward \(template.maximumRepetitions) reps."
            )
        case .timed:
            return ProgressionRecommendation(
                title: "Add a few seconds",
                detail: "Keep the same position and build toward \(template.maximumRepetitions) seconds."
            )
        }
    }

    static func comparison(
        for current: ExercisePerformance,
        measurement: ExerciseTemplate.Measurement,
        among performances: [ExercisePerformance]
    ) -> String? {
        guard let previous = performances
            .filter({ $0.date < current.date })
            .max(by: { $0.date < $1.date }) else { return nil }

        switch measurement {
        case .weighted:
            let loadDelta = (current.topSet?.weight ?? 0) - (previous.topSet?.weight ?? 0)
            if loadDelta != 0 {
                return "\(loadDelta > 0 ? "+" : "")\(loadDelta.formatted(.number.precision(.fractionLength(0...2)))) kg"
            }
            let volumeDelta = current.totalVolume - previous.totalVolume
            if volumeDelta != 0 {
                return "\(volumeDelta > 0 ? "+" : "")\(Int(volumeDelta)) kg volume"
            }
            let repDelta = current.bestRepetitions - previous.bestRepetitions
            if repDelta != 0 {
                return "\(repDelta > 0 ? "+" : "")\(repDelta) reps"
            }
            return "Matched previous"
        case .bodyweight, .timed:
            let delta = current.bestRepetitions - previous.bestRepetitions
            if delta == 0 { return "Matched previous" }
            return "\(delta > 0 ? "+" : "")\(delta) \(measurement == .timed ? "sec" : "reps")"
        }
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

            ScrollView {
                LazyVStack(spacing: 18) {
                    RawScreenTitle(index: "03", title: "Progress", detail: "12 WEEKS")
                        .padding(.horizontal, -20)
                        .padding(.bottom, 2)

                    exerciseOverview

                    if let recommendation {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("NEXT SESSION")
                                .font(.caption2.weight(.semibold))
                                .tracking(1.6)
                                .foregroundStyle(InkPalette.softInk)
                            Text(recommendation.title)
                                .font(.system(.headline, design: .serif, weight: .semibold))
                                .foregroundStyle(InkPalette.cinnabar)
                            Text(recommendation.detail)
                                .font(.system(.caption, design: .serif))
                                .foregroundStyle(InkPalette.softInk)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if performances.isEmpty {
                        EmptyExerciseRecord()
                    } else {
                        summary
                        if performances.count == 1 {
                            baseline
                        } else {
                            trendChart
                            sessionHistory
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 30)
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

    private var recommendation: ProgressionRecommendation? {
        ProgressionEngine.recommendation(for: exercise, performances: performances)
    }

    private var progressHeader: some View {
        InkTextHeader(
            title: exercise.name.uppercased(),
            leadingTitle: "Back",
            leadingAction: { dismiss() }
        )
    }

    private var exerciseOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                DemonstrationImage(assetName: exercise.assetName, outlined: false)
                    .frame(width: 132, height: 118)

                VStack(alignment: .leading, spacing: 8) {
                    Text("PRESCRIPTION")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.5)
                        .foregroundStyle(InkPalette.softInk)
                    Text(exercise.targetText)
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(InkPalette.ink)
                        .monospacedDigit()

                    if let latest = performances.first {
                        Text("Last · \(sessionSummary(latest))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(InkPalette.cinnabar)
                            .lineLimit(2)
                            .minimumScaleFactor(0.76)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !exercise.formCues.isEmpty {
                InkDivider()

                Text("FORM")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(InkPalette.softInk)

                VStack(alignment: .leading, spacing: 11) {
                    ForEach(Array(exercise.formCues.enumerated()), id: \.offset) { index, cue in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(String(format: "%02d", index + 1))
                                .font(.caption2.monospacedDigit().weight(.semibold))
                                .foregroundStyle(InkPalette.cinnabar)
                                .frame(width: 20, alignment: .leading)
                            Text(cue)
                                .font(.system(.subheadline, design: .serif))
                                .foregroundStyle(InkPalette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 2)
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
        .background(InkPalette.raisedPaper)
        .overlay { Rectangle().stroke(InkPalette.bronze.opacity(0.62), lineWidth: 1) }
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
                            .padding(.horizontal, 12)
                            .frame(minHeight: 40)
                            .background {
                                if selectedMetric == metric {
                                    Rectangle()
                                        .fill(InkPalette.cinnabar)
                                }
                            }
                            .foregroundStyle(selectedMetric == metric ? InkPalette.raisedPaper : InkPalette.softInk)
                            .overlay { Rectangle().stroke(InkPalette.bronze.opacity(0.72), lineWidth: 1) }
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }

            Chart(performances.reversed()) { performance in
                LineMark(
                    x: .value("Date", performance.date),
                    y: .value(selectedMetric.axisLabel(for: exercise.measurement), selectedMetric.value(for: performance))
                )
                .foregroundStyle(InkPalette.cinnabar)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .square, lineJoin: .bevel))

                PointMark(
                    x: .value("Date", performance.date),
                    y: .value(selectedMetric.axisLabel(for: exercise.measurement), selectedMetric.value(for: performance))
                )
                .foregroundStyle(InkPalette.bronze)
                .symbolSize(42)
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

    private var baseline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BASELINE")
                .font(.caption2.weight(.semibold))
                .tracking(1.8)
                .foregroundStyle(InkPalette.softInk)
            HStack {
                Text(shortDate(performances[0].date))
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(InkPalette.softInk)
                Spacer()
                Text(sessionSummary(performances[0]))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(InkPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(minHeight: 48)
            Text("A trend will appear after the next recorded session.")
                .font(.system(.caption, design: .serif))
                .foregroundStyle(InkPalette.softInk.opacity(0.78))
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

private struct EmptyExerciseRecord: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("No completed sets yet")
                .font(.system(.headline, design: .serif, weight: .semibold))
                .foregroundStyle(InkPalette.ink)
            Text("Complete this movement in a session to begin its record.")
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(InkPalette.softInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 38)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
