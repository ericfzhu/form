import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]
    @State private var saveErrorMessage: String?

    var body: some View {
        ZStack {
            PaperBackground()

            if workouts.isEmpty {
                EmptyHistoryView()
            } else {
                List {
                    HistoryWeeklySummary(workouts: workouts)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(
                            EdgeInsets(top: 10, leading: 20, bottom: 14, trailing: 20)
                        )

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
        .alert("Couldn’t delete workout", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "")
        }
    }

    private func delete(_ workout: WorkoutRecord) {
        withAnimation(.easeOut(duration: 0.2)) {
            modelContext.delete(workout)
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "The workout remains in History. Try again."
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

private struct HistoryWeeklySummary: View {
    let workouts: [WorkoutRecord]

    private var weeklyWorkouts: [WorkoutRecord] {
        workouts.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }
    }

    private var minutes: Int {
        weeklyWorkouts.reduce(0) { $0 + max(1, Int($1.duration / 60)) }
    }

    private var sets: Int {
        weeklyWorkouts.reduce(0) { result, workout in
            result + workout.exercises.reduce(0) { $0 + $1.sets.count }
        }
    }

    private var nextRoutineID: String {
        guard let latestName = workouts.first?.routineName,
              let index = WorkoutCatalog.routines.firstIndex(where: { $0.name == latestName }) else {
            return WorkoutCatalog.routines[0].id
        }
        return WorkoutCatalog.routines[(index + 1) % WorkoutCatalog.routines.count].id
    }

    private var prCount: Int {
        weeklyWorkouts.reduce(0) { total, workout in
            total + workout.exercises.reduce(0) { exerciseTotal, exercise in
                let performances = ProgressionEngine.performances(for: exercise.name, in: workouts)
                guard let performance = performances.first(where: {
                    $0.id == workout.persistentModelID
                }) else { return exerciseTotal }
                let measurement = WorkoutCatalog.exercise(named: exercise.name)?.measurement
                    ?? (exercise.sets.contains { $0.weight > 0 } ? .weighted : .bodyweight)
                return exerciseTotal + ProgressionEngine.personalRecords(
                    for: performance,
                    measurement: measurement,
                    among: performances
                ).count
            }
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
                Text("Next · \(nextRoutineID)")
                Spacer()
                Text("\(prCount) PR\(prCount == 1 ? "" : "s")")
            }
            .font(.system(.caption, design: .serif, weight: .semibold))
            .foregroundStyle(InkPalette.cinnabar)
            .monospacedDigit()
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(InkPalette.raisedPaper.opacity(0.76))
        )
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(InkPalette.ink)
                .monospacedDigit()
            Text(label)
                .font(.caption2.weight(.semibold))
                .tracking(1)
                .foregroundStyle(InkPalette.softInk)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WorkoutHistoryDetail: View {
    let workout: WorkoutRecord
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]
    @State private var showingEditor = false

    private var completedExercises: [ExerciseRecord] {
        workout.exercises.filter { !$0.sets.isEmpty }.sorted { $0.order < $1.order }
    }

    private var skippedExerciseCount: Int {
        workout.exercises.filter(\.sets.isEmpty).count
    }

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

                    ForEach(completedExercises) { exercise in
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

                    if skippedExerciseCount > 0 {
                        HStack {
                            Text("SKIPPED")
                                .font(.caption2.weight(.semibold))
                                .tracking(1.5)
                                .foregroundStyle(InkPalette.softInk)
                            Spacer()
                            Text("\(skippedExerciseCount) movement\(skippedExerciseCount == 1 ? "" : "s")")
                                .font(.system(.subheadline, design: .serif))
                                .foregroundStyle(InkPalette.softInk)
                                .monospacedDigit()
                        }
                        .frame(minHeight: 48)
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
    let record: ExerciseRecord?
    let template: ExerciseTemplate
    var sets: [EditableSetDraft]
}

private struct WorkoutEditorView: View {
    let workout: WorkoutRecord

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var date: Date
    @State private var routineName: String
    @State private var durationMinutes: Double
    @State private var exercises: [EditableExerciseDraft]
    @State private var cardioEntries: [CardioDraft]
    @State private var saveErrorMessage: String?

    init(workout: WorkoutRecord) {
        self.workout = workout
        _date = State(initialValue: workout.date)
        _routineName = State(initialValue: workout.routineName)
        _durationMinutes = State(initialValue: max(1, workout.duration / 60))
        _exercises = State(initialValue: workout.exercises
            .sorted { $0.order < $1.order }
            .map { exercise in
                EditableExerciseDraft(
                    record: exercise,
                    template: WorkoutCatalog.exercise(named: exercise.name)
                        ?? ExerciseTemplate(
                            id: exercise.assetName,
                            name: exercise.name,
                            assetName: exercise.assetName,
                            sets: max(1, exercise.sets.count),
                            minimumRepetitions: 1,
                            maximumRepetitions: 20,
                            measurement: exercise.sets.contains { $0.weight > 0 } ? .weighted : .bodyweight
                        ),
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
                        EditableExerciseCard(
                            exercise: $exercise,
                            canMoveEarlier: index(of: exercise.id) > 0,
                            canMoveLater: index(of: exercise.id) < exercises.count - 1,
                            moveEarlier: { moveExercise(exercise.id, offset: -1) },
                            moveLater: { moveExercise(exercise.id, offset: 1) },
                            markSkipped: { markSkipped(exercise.id) },
                            remove: {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    exercises.removeAll { $0.id == exercise.id }
                                }
                            }
                        )
                    }

                    addExerciseMenu

                    CardioLoggingSection(entries: $cardioEntries)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 36)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .keyboardDismissToolbar()
        .safeAreaInset(edge: .top, spacing: 0) {
            editorHeader
        }
        .interactiveDismissDisabled()
        .alert("Couldn’t save changes", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "")
        }
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

            VStack(alignment: .leading, spacing: 5) {
                Text("SESSION NAME")
                    .font(.caption2.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(InkPalette.softInk)
                TextField("Workout", text: $routineName)
                    .inkInput()
            }

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

    private var addExerciseMenu: some View {
        Menu {
            ForEach(availableExercises) { template in
                Button(template.name) {
                    exercises.append(
                        EditableExerciseDraft(
                            record: nil,
                            template: template,
                            sets: (0..<template.sets).map { _ in
                                EditableSetDraft(
                                    weight: 0,
                                    repetitions: template.minimumRepetitions
                                )
                            }
                        )
                    )
                }
            }
        } label: {
            Text("Add exercise")
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(InkPalette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(InkPalette.raisedPaper.opacity(0.72))
                )
        }
    }

    private var availableExercises: [ExerciseTemplate] {
        WorkoutCatalog.routines
            .flatMap(\.exercises)
            .uniquedByName()
            .filter { template in
                !exercises.contains { $0.template.name == template.name }
            }
    }

    private func index(of id: UUID) -> Int {
        exercises.firstIndex { $0.id == id } ?? 0
    }

    private func moveExercise(_ id: UUID, offset: Int) {
        let source = index(of: id)
        let destination = source + offset
        guard exercises.indices.contains(source), exercises.indices.contains(destination) else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            exercises.swapAt(source, destination)
        }
    }

    private func markSkipped(_ id: UUID) {
        guard let index = exercises.firstIndex(where: { $0.id == id }) else { return }
        exercises[index].sets = []
    }

    private func save() {
        workout.date = date
        workout.routineName = routineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Workout"
            : routineName.trimmingCharacters(in: .whitespacesAndNewlines)
        workout.duration = max(60, durationMinutes * 60)

        let retainedRecords = Set(exercises.compactMap { $0.record?.persistentModelID })
        for existing in workout.exercises where !retainedRecords.contains(existing.persistentModelID) {
            modelContext.delete(existing)
        }

        var savedExercises: [ExerciseRecord] = []
        for (exerciseIndex, exerciseDraft) in exercises.enumerated() {
            if exerciseDraft.record == nil && exerciseDraft.sets.isEmpty { continue }
            let record = exerciseDraft.record ?? ExerciseRecord(
                name: exerciseDraft.template.name,
                assetName: exerciseDraft.template.assetName,
                order: exerciseIndex
            )
            record.order = exerciseIndex
            let oldSets = record.sets
            record.sets = []
            oldSets.forEach(modelContext.delete)
            record.sets = exerciseDraft.sets.enumerated().map { index, set in
                SetRecord(
                    order: index,
                    weight: exerciseDraft.template.measurement == .weighted ? max(0, set.weight) : 0,
                    repetitions: max(0, set.repetitions)
                )
            }
            savedExercises.append(record)
        }
        workout.exercises = savedExercises

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

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Your edits are still on this screen. Try saving again."
        }
    }
}

private struct EditableExerciseCard: View {
    @Binding var exercise: EditableExerciseDraft
    let canMoveEarlier: Bool
    let canMoveLater: Bool
    let moveEarlier: () -> Void
    let moveLater: () -> Void
    let markSkipped: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                DemonstrationImage(assetName: exercise.template.assetName)
                    .frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 5) {
                    Text(exercise.template.name)
                        .font(.system(.headline, design: .serif, weight: .semibold))
                        .foregroundStyle(InkPalette.ink)
                    if exercise.sets.isEmpty {
                        Text("SKIPPED")
                            .font(.caption2.weight(.semibold))
                            .tracking(1.2)
                            .foregroundStyle(InkPalette.cinnabar)
                    }
                }
                Spacer()

                Menu("Manage") {
                    Button("Move earlier", action: moveEarlier)
                        .disabled(!canMoveEarlier)
                    Button("Move later", action: moveLater)
                        .disabled(!canMoveLater)
                    Button("Mark as skipped", action: markSkipped)
                        .disabled(exercise.sets.isEmpty)
                    Button("Remove exercise", role: .destructive, action: remove)
                }
                .font(.system(.caption, design: .serif, weight: .semibold))
                .tint(InkPalette.softInk)
                .frame(minWidth: 58, minHeight: 44)
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

                    if exercise.template.measurement == .weighted {
                        editField(exercise.template.loadLabel, value: $set.weight)
                    }

                    editRepetitionField(
                        exercise.template.measurement == .timed ? "SEC" : "REPS",
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

private extension Array where Element == ExerciseTemplate {
    func uniquedByName() -> [ExerciseTemplate] {
        var seen = Set<String>()
        return filter { seen.insert($0.name).inserted }
    }
}
