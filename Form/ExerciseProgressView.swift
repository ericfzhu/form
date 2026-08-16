import Charts
import SwiftData
import SwiftUI

struct ExerciseProgressView: View {
    let exercise: ExerciseTemplate

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]
    @State private var selectedMetric: TrendMetric = .load
    @State private var selectedPeriod: ProgressPeriod = .twelveWeeks

    private var allPerformances: [ExercisePerformance] {
        ProgressionEngine.performances(for: exercise, in: workouts)
    }

    private var performances: [ExercisePerformance] {
        allPerformances.filter { selectedPeriod.includes($0.date) }
    }

    private var availableMetrics: [TrendMetric] {
        switch exercise.measurement {
        case .weighted: [.load, .estimatedOneRepMax, .repetitions, .volume]
        case .weightedTimed: [.load, .repetitions]
        case .bodyweight, .timed: [.repetitions]
        }
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(spacing: 18) {
                    RawScreenTitle(
                        index: "03",
                        title: "Progress",
                        detail: selectedPeriod.headerTitle
                    )
                    .padding(.horizontal, -20)
                    .padding(.bottom, 2)

                    periodControl
                    exerciseOverview

                    if let recommendation = ProgressionEngine.recommendation(
                        for: exercise,
                        performances: allPerformances
                    ) {
                        recommendationView(recommendation)
                    }

                    if performances.isEmpty {
                        EmptyExerciseRecord(period: selectedPeriod)
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
        .background { InteractivePopGestureBridge(isEnabled: true) }
        .safeAreaInset(edge: .top, spacing: 0) {
            InkTextHeader(
                title: exercise.name.uppercased(),
                leadingTitle: "Back",
                leadingAction: { dismiss() }
            )
        }
        .onAppear {
            if !availableMetrics.contains(selectedMetric) {
                selectedMetric = .repetitions
            }
        }
    }

    private var periodControl: some View {
        HStack(spacing: 0) {
            ForEach(ProgressPeriod.allCases) { period in
                Button {
                    selectedPeriod = period
                } label: {
                    Text(period.title.uppercased())
                        .font(.system(size: 9, weight: .semibold, design: .serif))
                        .tracking(0.8)
                        .foregroundStyle(selectedPeriod == period
                            ? InkPalette.raisedPaper
                            : InkPalette.softInk)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(selectedPeriod == period
                            ? InkPalette.cinnabar
                            : InkPalette.raisedPaper)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .overlay { Rectangle().stroke(InkPalette.bronze.opacity(0.72), lineWidth: 1) }
    }

    private var exerciseOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                DemonstrationImage(assetName: exercise.assetName, outlined: false)
                    .frame(width: 132, height: 118)
                VStack(alignment: .leading, spacing: 8) {
                    Text("TARGET")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.5)
                        .foregroundStyle(InkPalette.softInk)
                    Text(exercise.targetText)
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .monospacedDigit()
                    if let latest = allPerformances.first {
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
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private func recommendationView(
        _ recommendation: ProgressionRecommendation
    ) -> some View {
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
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ForEach(availableMetrics, id: \.self) { metric in
                    Button { selectedMetric = metric } label: {
                        Text(metric.title(for: exercise.measurement))
                            .font(.system(.caption, design: .serif, weight: selectedMetric == metric ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 40)
                            .background {
                                if selectedMetric == metric {
                                    Rectangle().fill(InkPalette.cinnabar)
                                }
                            }
                            .foregroundStyle(selectedMetric == metric
                                ? InkPalette.raisedPaper
                                : InkPalette.softInk)
                            .overlay { Rectangle().stroke(InkPalette.bronze.opacity(0.72), lineWidth: 1) }
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }

            Chart(performances.reversed()) { performance in
                LineMark(
                    x: .value("Date", performance.date),
                    y: .value(
                        selectedMetric.axisLabel(for: exercise.measurement),
                        selectedMetric.value(for: performance)
                    )
                )
                .foregroundStyle(InkPalette.cinnabar)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .square, lineJoin: .bevel))

                PointMark(
                    x: .value("Date", performance.date),
                    y: .value(
                        selectedMetric.axisLabel(for: exercise.measurement),
                        selectedMetric.value(for: performance)
                    )
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(minHeight: 48)
            Text("A trend will appear after the next recorded session in this period.")
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
                if performance.id != performances.last?.id { InkDivider() }
            }
        }
    }

    private var bestSummary: String {
        switch exercise.measurement {
        case .weighted, .weightedTimed:
            guard let best = performances.compactMap(\.topSet).max(by: {
                if $0.weight == $1.weight { return $0.repetitions < $1.repetitions }
                return $0.weight < $1.weight
            }) else { return "—" }
            return WorkoutValueFormatter.setText(
                weight: best.weight,
                repetitions: best.repetitions,
                template: exercise
            )
        case .bodyweight:
            return "\(performances.map(\.bestRepetitions).max() ?? 0) reps"
        case .timed:
            return "\(performances.map(\.bestRepetitions).max() ?? 0) sec"
        }
    }

    private var bestOneRepMax: String {
        "\(WorkoutValueFormatter.weight(performances.map(\.estimatedOneRepMax).max() ?? 0)) kg"
    }

    private func records(for performance: ExercisePerformance) -> [ProgressRecord] {
        ProgressionEngine.personalRecords(
            for: performance,
            measurement: exercise.measurement,
            among: allPerformances
        )
    }

    private func sessionSummary(_ performance: ExercisePerformance) -> String {
        switch exercise.measurement {
        case .weighted:
            guard let topSet = performance.topSet else { return "—" }
            return "\(WorkoutValueFormatter.setText(weight: topSet.weight, repetitions: topSet.repetitions, template: exercise)) · \(Int(performance.totalVolume)) kg volume"
        case .weightedTimed:
            guard let topSet = performance.topSet else { return "—" }
            return WorkoutValueFormatter.setText(
                weight: topSet.weight,
                repetitions: topSet.repetitions,
                template: exercise
            )
        case .bodyweight:
            return "Best \(performance.bestRepetitions) reps"
        case .timed:
            return "Best \(performance.bestRepetitions) sec"
        }
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }
}

