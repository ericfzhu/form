import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]

    var body: some View {
        ZStack {
            PaperBackground()

            if workouts.isEmpty {
                EmptyHistoryView()
            } else {
                List {
                    ForEach(workouts) { workout in
                        NavigationLink(value: workout) {
                            HistoryCard(workout: workout)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(
                            EdgeInsets(top: 7, leading: 20, bottom: 7, trailing: 20)
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                delete(workout)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(InkPalette.cinnabar)
                        }
                        .contextMenu {
                            Button("Delete workout", role: .destructive) {
                                delete(workout)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(.vertical, 15, for: .scrollContent)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func delete(_ workout: WorkoutRecord) {
        withAnimation(.easeOut(duration: 0.2)) {
            modelContext.delete(workout)
        }
    }
}

private struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 18) {
            DemonstrationImage(assetName: "plank", outlined: false)
                .frame(width: 230, height: 180)
                .mask(
                    LinearGradient(
                        colors: [.clear, .black, .black, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("No workouts yet")
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(InkPalette.ink)
            InkDivider()
                .frame(width: 120)
            Text("Completed workouts will appear here.")
                .font(.system(.body, design: .serif))
                .foregroundStyle(InkPalette.softInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 42)
        }
        .padding(.bottom, 54)
    }
}

private struct HistoryCard: View {
    let workout: WorkoutRecord

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text(workout.date.formatted(.dateTime.day()))
                    .font(.system(size: 31, weight: .medium, design: .serif))
                    .foregroundStyle(InkPalette.ink)
                Text(workout.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(1.4)
                    .foregroundStyle(InkPalette.softInk)
            }
            .frame(width: 62)

            Capsule()
                .fill(InkPalette.ink.opacity(0.18))
                .frame(width: 1, height: 58)

            VStack(alignment: .leading, spacing: 6) {
                Text(workout.routineName)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(InkPalette.ink)
                Text(detailText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(InkPalette.softInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(InkPalette.softInk)
                .frame(width: 40, height: 40)
        }
        .padding(16)
        .inkCard()
    }

    private func durationText(_ duration: TimeInterval) -> String {
        "\(max(1, Int(duration / 60))) min"
    }

    private var completedMovementCount: Int {
        workout.exercises.filter { !$0.sets.isEmpty }.count
    }

    private var detailText: String {
        var parts = [
            durationText(workout.duration),
            "\(completedMovementCount) movements"
        ]
        let cardioMinutes = Int(workout.cardioEntries.reduce(0) { $0 + $1.durationMinutes })
        if cardioMinutes > 0 {
            parts.append("\(cardioMinutes)m cardio")
        }
        return parts.joined(separator: " · ")
    }
}

struct WorkoutHistoryDetail: View {
    let workout: WorkoutRecord
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]
    @State private var showingEditor = false

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(InkPalette.cinnabar)
                                .frame(width: 9, height: 9)
                            Text(workout.date.formatted(date: .long, time: .omitted).uppercased())
                                .font(.caption.weight(.semibold))
                                .tracking(1.8)
                                .foregroundStyle(InkPalette.softInk)
                        }
                        InkDivider().padding(.top, 3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 6)

                    ForEach(workout.exercises.sorted { $0.order < $1.order }) { exercise in
                        if let template = WorkoutCatalog.exercise(named: exercise.name) {
                            NavigationLink(value: template) {
                                HistoryExerciseCard(
                                    exercise: exercise,
                                    records: records(for: exercise)
                                )
                            }
                            .buttonStyle(PressableButtonStyle())
                        } else {
                            HistoryExerciseCard(
                                exercise: exercise,
                                records: records(for: exercise)
                            )
                        }
                    }

                    if !workout.cardioEntries.isEmpty {
                        cardioHistory
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background {
            InteractivePopGestureBridge(isEnabled: true)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            InkTextHeader(
                title: workout.routineName.uppercased(),
                leadingTitle: "Back",
                leadingAction: { dismiss() },
                trailingTitle: "Edit",
                trailingAction: { showingEditor = true }
            )
        }
        .fullScreenCover(isPresented: $showingEditor) {
            WorkoutEditorView(workout: workout)
        }
    }

    private var cardioHistory: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CARDIO")
                .font(.caption2.weight(.semibold))
                .tracking(1.8)
                .foregroundStyle(InkPalette.softInk)

            ForEach(workout.cardioEntries.sorted { $0.order < $1.order }) { entry in
                CardioHistoryCard(entry: entry)
            }
        }
        .padding(.top, 4)
    }

    private func records(for exercise: ExerciseRecord) -> [ProgressRecord] {
        let performances = ProgressionEngine.performances(
            for: exercise.name,
            in: workouts
        )
        guard let performance = performances.first(where: { $0.id == workout.persistentModelID }) else {
            return []
        }
        let measurement = WorkoutCatalog.exercise(named: exercise.name)?.measurement
            ?? (exercise.sets.contains { $0.weight > 0 } ? .weighted : .bodyweight)
        return ProgressionEngine.personalRecords(
            for: performance,
            measurement: measurement,
            among: performances
        )
    }
}

private struct HistoryExerciseCard: View {
    let exercise: ExerciseRecord
    let records: [ProgressRecord]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                DemonstrationImage(assetName: exercise.assetName)
                    .frame(width: 86, height: 86)
                VStack(alignment: .leading, spacing: 7) {
                    Text(exercise.name)
                        .font(.system(.headline, design: .serif, weight: .semibold))
                        .foregroundStyle(InkPalette.ink)
                    if !records.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(records.prefix(2)) { record in
                                Text(record.shortTitle)
                                    .font(.caption2.weight(.bold))
                                    .tracking(0.8)
                                    .foregroundStyle(InkPalette.cinnabar)
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(11)

            if exercise.sets.isEmpty {
                Text("No completed sets")
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(InkPalette.softInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding([.horizontal, .bottom], 16)
            } else {
                InkDivider()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 3)

                ForEach(exercise.sets.sorted { $0.order < $1.order }) { set in
                    HStack {
                        Text("Set \(set.order + 1)")
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(InkPalette.softInk)
                        Spacer()
                        Text(setText(set))
                            .font(.body.monospacedDigit().weight(.semibold))
                            .foregroundStyle(InkPalette.ink)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                }
            }
        }
        .inkCard()
    }

    private func setText(_ set: SetRecord) -> String {
        if set.weight > 0 {
            return "\(set.weight.formatted(.number.precision(.fractionLength(0...1)))) kg × \(set.repetitions)"
        }
        return "\(set.repetitions) reps"
    }
}

private struct CardioHistoryCard: View {
    let entry: CardioRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(entry.kind.title)
                .font(.system(.headline, design: .serif, weight: .semibold))
                .foregroundStyle(InkPalette.ink)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 112), alignment: .leading)],
                alignment: .leading,
                spacing: 12
            ) {
                metric("\(number(entry.durationMinutes)) min", label: "TIME")
                if entry.distanceKilometers > 0 {
                    metric("\(number(entry.distanceKilometers)) km", label: "DISTANCE")
                }
                if entry.averageSpeed > 0 {
                    metric("\(number(entry.averageSpeed)) km/h", label: "SPEED")
                }
                if entry.kind.supportsIncline && entry.incline > 0 {
                    metric("\(number(entry.incline))%", label: "INCLINE")
                }
            }
        }
        .padding(16)
        .inkCard()
    }

    private func metric(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .tracking(0.9)
                .foregroundStyle(InkPalette.softInk)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(InkPalette.ink)
        }
    }

    private func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

private struct EditableSetDraft: Identifiable {
    let id = UUID()
    var weight: Double
    var repetitions: Int
}

private struct EditableExerciseDraft: Identifiable {
    let id = UUID()
    let record: ExerciseRecord
    let measurement: ExerciseTemplate.Measurement
    var sets: [EditableSetDraft]
}

private struct WorkoutEditorView: View {
    let workout: WorkoutRecord

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var date: Date
    @State private var durationMinutes: Double
    @State private var exercises: [EditableExerciseDraft]
    @State private var cardioEntries: [CardioDraft]

    init(workout: WorkoutRecord) {
        self.workout = workout
        _date = State(initialValue: workout.date)
        _durationMinutes = State(initialValue: max(1, workout.duration / 60))
        _exercises = State(initialValue: workout.exercises
            .sorted { $0.order < $1.order }
            .map { exercise in
                EditableExerciseDraft(
                    record: exercise,
                    measurement: WorkoutCatalog.exercise(named: exercise.name)?.measurement
                        ?? (exercise.sets.contains { $0.weight > 0 } ? .weighted : .bodyweight),
                    sets: exercise.sets
                        .sorted { $0.order < $1.order }
                        .map {
                            EditableSetDraft(
                                weight: $0.weight,
                                repetitions: $0.repetitions
                            )
                        }
                )
            })
        _cardioEntries = State(initialValue: workout.cardioEntries
            .sorted { $0.order < $1.order }
            .map(CardioDraft.init(record:)))
    }

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                LazyVStack(spacing: 18) {
                    sessionDetails

                    ForEach($exercises) { $exercise in
                        EditableExerciseCard(exercise: $exercise)
                    }

                    CardioLoggingSection(entries: $cardioEntries)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 36)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            editorHeader
        }
        .interactiveDismissDisabled()
    }

    private var editorHeader: some View {
        InkTextHeader(
            title: "EDIT SESSION",
            leadingTitle: "Cancel",
            leadingAction: { dismiss() },
            trailingTitle: "Save",
            trailingAction: save
        )
    }

    private var sessionDetails: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SESSION")
                .font(.caption2.weight(.semibold))
                .tracking(1.8)
                .foregroundStyle(InkPalette.softInk)

            DatePicker(
                "Date and time",
                selection: $date,
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(.system(.body, design: .serif))
            .tint(InkPalette.cinnabar)

            VStack(alignment: .leading, spacing: 5) {
                Text("DURATION · MINUTES")
                    .font(.caption2.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(InkPalette.softInk)
                TextField(
                    "60",
                    value: $durationMinutes,
                    format: .number.precision(.fractionLength(0...1))
                )
                .keyboardType(.decimalPad)
                .inkInput()
            }
        }
        .padding(16)
        .inkCard()
    }

    private func save() {
        workout.date = date
        workout.duration = max(60, durationMinutes * 60)

        for exerciseDraft in exercises {
            let oldSets = exerciseDraft.record.sets
            exerciseDraft.record.sets = []
            oldSets.forEach(modelContext.delete)
            exerciseDraft.record.sets = exerciseDraft.sets.enumerated().map { index, set in
                SetRecord(
                    order: index,
                    weight: exerciseDraft.measurement == .weighted ? max(0, set.weight) : 0,
                    repetitions: max(0, set.repetitions)
                )
            }
        }

        let oldCardioEntries = workout.cardioEntries
        workout.cardioEntries = []
        oldCardioEntries.forEach(modelContext.delete)
        workout.cardioEntries = cardioEntries.enumerated().compactMap { index, entry in
            guard entry.durationMinutes > 0 else { return nil }
            return CardioRecord(
                kind: entry.kind,
                order: index,
                durationMinutes: entry.durationMinutes,
                distanceKilometers: max(0, entry.distanceKilometers),
                averageSpeed: max(0, entry.averageSpeed),
                incline: entry.kind.supportsIncline ? max(0, entry.incline) : 0
            )
        }

        try? modelContext.save()
        dismiss()
    }
}

private struct EditableExerciseCard: View {
    @Binding var exercise: EditableExerciseDraft

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                DemonstrationImage(assetName: exercise.record.assetName)
                    .frame(width: 72, height: 72)
                Text(exercise.record.name)
                    .font(.system(.headline, design: .serif, weight: .semibold))
                    .foregroundStyle(InkPalette.ink)
                Spacer()
            }
            .padding(11)

            InkDivider()
                .padding(.horizontal, 14)
                .padding(.vertical, 4)

            ForEach($exercise.sets) { $set in
                HStack(spacing: 10) {
                    Text("\((exercise.sets.firstIndex { $0.id == set.id } ?? 0) + 1)")
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundStyle(InkPalette.softInk)
                        .frame(width: 28, alignment: .leading)

                    if exercise.measurement == .weighted {
                        editField("KG", value: $set.weight)
                    }

                    editRepetitionField(
                        exercise.measurement == .timed ? "SEC" : "REPS",
                        value: $set.repetitions
                    )

                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            exercise.sets.removeAll { $0.id == set.id }
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(InkPalette.cinnabar)
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Delete set")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
            }

            Button {
                let last = exercise.sets.last
                withAnimation(.easeOut(duration: 0.18)) {
                    exercise.sets.append(
                        EditableSetDraft(
                            weight: last?.weight ?? 0,
                            repetitions: last?.repetitions ?? 8
                        )
                    )
                }
            } label: {
                Text("Add set")
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .foregroundStyle(InkPalette.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .inkCard()
    }

    private func editField(_ label: String, value: Binding<Double>) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .tracking(1)
                .foregroundStyle(InkPalette.softInk)
            TextField(
                "0",
                value: value,
                format: .number.precision(.fractionLength(0...1))
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .inkInput()
        }
        .frame(maxWidth: .infinity)
    }

    private func editRepetitionField(_ label: String, value: Binding<Int>) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .tracking(1)
                .foregroundStyle(InkPalette.softInk)
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .inkInput()
        }
        .frame(maxWidth: .infinity)
    }
}
