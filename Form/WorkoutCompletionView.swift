import SwiftData
import SwiftUI

struct WorkoutCompletionView: View {
    let record: WorkoutRecord
    let done: () -> Void
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false

    private var completedExercises: [ExerciseRecord] {
        record.exercises.filter { !$0.sets.isEmpty }.sorted { $0.order < $1.order }
    }

    private var completedSetCount: Int {
        completedExercises.reduce(0) { $0 + $1.sets.filter { $0.kind == .working }.count }
    }

    private var warmupSetCount: Int {
        completedExercises.reduce(0) { $0 + $1.sets.filter { $0.kind == .warmup }.count }
    }

    private var cardioMinutes: Double {
        record.cardioEntries.reduce(0) { $0 + $1.durationMinutes }
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    savedHeading
                    Image("paper-finished")
                        .resizable().scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: typeSize.isAccessibilitySize ? 120 : 180)
                        .scaleEffect(reduceMotion || arrived ? 1 : 0.95, anchor: .bottom)
                        .offset(y: reduceMotion || arrived ? 0 : 8)
                        .accessibilityHidden(true)
                    sessionReceipt
                    if let observation = SessionObservation.message(for: record, in: workouts) {
                        HStack(alignment: .top, spacing: 12) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(InkPalette.salvia).frame(width: 3)
                                .accessibilityHidden(true)
                            Text(observation)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    if completedExercises.isEmpty && record.cardioEntries.isEmpty {
                        Text("No sets or cardio recorded.")
                            .font(.subheadline).foregroundStyle(InkPalette.softInk)
                    } else {
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(completedExercises) { exercise in
                                    completionRow(exercise)
                                    InkDivider()
                                }
                                ForEach(record.cardioEntries.sorted { $0.order < $1.order }) { entry in
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(entry.kind.title).font(.body)
                                        Text("\(WorkoutValueFormatter.decimal(entry.durationMinutes)) min")
                                            .font(.subheadline.monospacedDigit())
                                            .foregroundStyle(InkPalette.softInk)
                                    }
                                    .accessibilityElement(children: .combine)
                                }
                            }
                            .padding(.top, 14)
                        } label: {
                            Text("View session").font(AtelierType.script(22))
                        }
                        .tint(InkPalette.ink)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            InkPrimaryButton(title: "Done", action: done)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(InkPalette.paper)
        }
        .onAppear {
            guard !arrived else { return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.78)) {
                arrived = true
            }
        }
    }

    private var savedHeading: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
        return layout {
            VStack(alignment: .leading, spacing: 6) {
                Text("Session saved")
                    .font(AtelierType.script(36))
                    .accessibilityAddTraits(.isHeader)
                Text(record.displayName)
                    .font(.subheadline).foregroundStyle(InkPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(InkPalette.salvia.opacity(0.3))
                RoundedRectangle(cornerRadius: 12).strokeBorder(InkPalette.ink, lineWidth: 1.5)
                InkCheckStroke()
                    .trim(from: 0, to: arrived ? 1 : 0)
                    .stroke(InkPalette.ink, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .padding(14)
            }
            .frame(width: 58, height: 58)
            .rotationEffect(.degrees(reduceMotion || arrived ? -6 : -14))
            .scaleEffect(reduceMotion || arrived ? 1 : 1.16)
            .accessibilityHidden(true)
        }
    }

    private var sessionReceipt: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(record.date.formatted(.dateTime.day().month(.wide).year()).lowercased())
                .font(AtelierType.script(18)).foregroundStyle(InkPalette.softInk)
            InkDivider()
            ViewThatFits(in: .horizontal) {
                if !typeSize.isAccessibilitySize {
                    HStack(alignment: .top, spacing: 24) { metrics }
                        .fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 16) { metrics }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InkPalette.salvia.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder private var metrics: some View {
        metric("Time", value: record.duration < 60 ? "<1 min" : WorkoutValueFormatter.durationMinutes(record.duration))
        if completedSetCount > 0 { metric("Working sets", value: "\(completedSetCount)") }
        if warmupSetCount > 0 { metric("Warm-up sets", value: "\(warmupSetCount)") }
        if cardioMinutes > 0 { metric("Cardio", value: "\(WorkoutValueFormatter.decimal(cardioMinutes)) min") }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(AtelierType.script(30)).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(InkPalette.softInk)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private func completionRow(_ exercise: ExerciseRecord) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return layout {
            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.name)
                    .font(.system(.body, design: .default))
                Text(setSummary(exercise))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(InkPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
                if let comparison = comparison(for: exercise) {
                    Text(comparison)
                        .font(.system(.caption2, design: .default, weight: .semibold))
                        .foregroundStyle(InkPalette.cinnabar)
                }
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            let records = personalRecords(for: exercise)
            if !records.isEmpty {
                VStack(alignment: .trailing, spacing: 3) {
                    ForEach(records.prefix(2)) { record in
                        Text(record.shortTitle)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(InkPalette.cinnabar)
                    }
                }
            }
        }
        .frame(minHeight: 58)
    }

    private func setSummary(_ exercise: ExerciseRecord) -> String {
        let template = WorkoutCatalog.exercise(for: exercise)
        return exercise.sets.sorted { $0.order < $1.order }.map { set in
            let prefix = set.kind == .warmup ? "Warm-up · " : ""
            return prefix + WorkoutValueFormatter.setText(set, template: template)
        }.joined(separator: " · ")
    }

    private func personalRecords(for exercise: ExerciseRecord) -> [ProgressRecord] {
        let performances = ProgressionEngine.performances(for: exercise, in: workouts)
        guard let performance = performances.first(where: {
            $0.id == record.persistentModelID
        }) else { return [] }
        let measurement = WorkoutCatalog.exercise(for: exercise)?.measurement
            ?? (exercise.sets.contains { $0.weight > 0 } ? .weighted : .bodyweight)
        return ProgressionEngine.personalRecords(
            for: performance,
            measurement: measurement,
            among: performances
        )
    }

    private func comparison(for exercise: ExerciseRecord) -> String? {
        let performances = ProgressionEngine.performances(for: exercise, in: workouts)
        guard let performance = performances.first(where: {
            $0.id == record.persistentModelID
        }) else { return nil }
        let measurement = WorkoutCatalog.exercise(for: exercise)?.measurement
            ?? (exercise.sets.contains { $0.weight > 0 } ? .weighted : .bodyweight)
        return ProgressionEngine.comparison(
            for: performance,
            measurement: measurement,
            among: performances
        )
    }
}

struct CompletionHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("form.").font(.custom("Gaegu-Regular", fixedSize: 26))
                .accessibilityHidden(true)
            Spacer()
            Text("workout record").font(.caption).foregroundStyle(InkPalette.softInk)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 52)
        .background(InkPalette.paper.ignoresSafeArea(edges: .top))
    }
}
