import SwiftUI
import SwiftData

private struct SetDraft: Identifiable {
    let id = UUID()
    var weight: Double
    var repetitions: Int
    var completed = false
}

private struct ExerciseDraft: Identifiable {
    let id: String
    let template: ExerciseTemplate
    var sets: [SetDraft]
}

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var history: [WorkoutRecord]

    let routine: RoutineTemplate
    let onDone: () -> Void
    let resumedFromSnapshot: Bool
    @State private var startedAt = Date()
    @State private var drafts: [ExerciseDraft]
    @State private var cardioDrafts: [CardioDraft] = []
    @State private var restEnd: Date?
    @State private var showingCancelConfirmation = false
    @State private var showingEmptyFinishConfirmation = false
    @State private var expandedExerciseID: String?
    @State private var completedRecord: WorkoutRecord?
    @State private var saveErrorMessage: String?

    init(
        routine: RoutineTemplate,
        snapshot: ActiveWorkoutSnapshot? = nil,
        onDone: @escaping () -> Void = {}
    ) {
        self.routine = routine
        self.onDone = onDone
        let validSnapshot = snapshot?.routineID == routine.id ? snapshot : nil
        resumedFromSnapshot = validSnapshot != nil
        _startedAt = State(initialValue: validSnapshot?.startedAt ?? Date())
        _drafts = State(initialValue: routine.exercises.map { exercise in
            let savedSets = validSnapshot?.exercises
                .first { $0.exerciseID == exercise.id }?.sets
            return ExerciseDraft(
                id: exercise.id,
                template: exercise,
                sets: savedSets?.map {
                    SetDraft(
                        weight: $0.weight,
                        repetitions: $0.repetitions,
                        completed: $0.completed
                    )
                } ?? (0..<exercise.sets).map { _ in
                    SetDraft(weight: 0, repetitions: exercise.minimumRepetitions)
                }
            )
        })
        _cardioDrafts = State(initialValue: validSnapshot?.cardio.map {
            CardioDraft(
                id: $0.id,
                kind: $0.kind,
                durationMinutes: $0.durationMinutes,
                distanceKilometers: $0.distanceKilometers,
                averageSpeed: $0.averageSpeed,
                incline: $0.incline
            )
        } ?? [])
        _expandedExerciseID = State(
            initialValue: validSnapshot?.expandedExerciseID ?? routine.exercises.first?.id
        )
    }

    var body: some View {
        Group {
            if let completedRecord {
                WorkoutCompletionView(record: completedRecord) {
                    onDone()
                    dismiss()
                }
            } else {
                workoutLogger
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Discard this workout?", isPresented: $showingCancelConfirmation) {
            Button("Discard workout", role: .destructive, action: discardWorkout)
            Button("Keep training", role: .cancel) {}
        }
        .confirmationDialog(
            "Finish without recording anything?",
            isPresented: $showingEmptyFinishConfirmation
        ) {
            Button("Finish empty session", role: .destructive, action: finishWorkout)
            Button("Keep training", role: .cancel) {}
        } message: {
            Text("No completed sets or cardio entries will be saved.")
        }
        .leadingEdgeSwipe {
            if completedRecord == nil {
                showingCancelConfirmation = true
            }
        }
        .alert("Couldn’t save workout", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "")
        }
        .onAppear {
            if !resumedFromSnapshot {
                prefillFromHistory()
            }
            persistDraft()
        }
        .onChange(of: currentSnapshot) { _, _ in
            persistDraft()
        }
    }

    private var workoutLogger: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach($drafts) { $draft in
                        ExerciseLoggingCard(
                            draft: $draft,
                            previous: ProgressionEngine.latestCompleted(
                                for: draft.template.name,
                                in: history
                            ),
                            recommendation: ProgressionEngine.recommendation(
                                for: draft.template,
                                performances: ProgressionEngine.performances(
                                    for: draft.template.name,
                                    in: history
                                )
                            ),
                            isExpanded: expandedExerciseID == draft.id,
                            toggleExpanded: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    expandedExerciseID = expandedExerciseID == draft.id
                                        ? nil
                                        : draft.id
                                }
                            },
                            didUpdateSet: { completed in
                                didUpdateSet(for: draft.id, completed: completed)
                            }
                        )
                        .id(draft.id)
                    }

                    CardioLoggingSection(entries: $cardioDrafts)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, restEnd == nil ? 96 : 158)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            ActiveWorkoutHeader(
                progress: "\(completedMovementCount) of \(drafts.count) movements"
            ) {
                showingCancelConfirmation = true
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 9) {
                if let restEnd {
                    RestTimer(end: restEnd) {
                        self.restEnd = nil
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                InkPrimaryButton(title: "Finish session", action: requestFinish)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(InkPalette.paper.opacity(0.95))
            .animation(.easeOut(duration: 0.2), value: restEnd)
        }
    }

    private var completedMovementCount: Int {
        drafts.filter(isExerciseComplete).count
    }

    private var hasRecordedWork: Bool {
        drafts.contains { $0.sets.contains(where: \.completed) }
            || cardioDrafts.contains { $0.durationMinutes > 0 }
    }

    private func requestFinish() {
        if hasRecordedWork {
            finishWorkout()
        } else {
            showingEmptyFinishConfirmation = true
        }
    }

    private var currentSnapshot: ActiveWorkoutSnapshot {
        ActiveWorkoutSnapshot(
            routineID: routine.id,
            startedAt: startedAt,
            exercises: drafts.map { draft in
                ActiveExerciseSnapshot(
                    exerciseID: draft.id,
                    sets: draft.sets.map {
                        ActiveSetSnapshot(
                            weight: $0.weight,
                            repetitions: $0.repetitions,
                            completed: $0.completed
                        )
                    }
                )
            },
            cardio: cardioDrafts.map {
                ActiveCardioSnapshot(
                    id: $0.id,
                    kind: $0.kind,
                    durationMinutes: $0.durationMinutes,
                    distanceKilometers: $0.distanceKilometers,
                    averageSpeed: $0.averageSpeed,
                    incline: $0.incline
                )
            },
            expandedExerciseID: expandedExerciseID
        )
    }

    private func persistDraft() {
        do {
            try ActiveWorkoutStore.save(currentSnapshot)
        } catch {
            saveErrorMessage = "Your active workout could not be preserved. \(error.localizedDescription)"
        }
    }

    private func discardWorkout() {
        ActiveWorkoutStore.clear()
        dismiss()
    }

    private func isExerciseComplete(_ draft: ExerciseDraft) -> Bool {
        draft.sets.filter(\.completed).count >= draft.template.sets
    }

    private func didUpdateSet(for exerciseID: String, completed: Bool) {
        guard completed else { return }
        restEnd = Date().addingTimeInterval(90)

        DispatchQueue.main.async {
            guard let index = drafts.firstIndex(where: { $0.id == exerciseID }),
                  isExerciseComplete(drafts[index]) else { return }

            let following = drafts.dropFirst(index + 1).first(where: {
                !isExerciseComplete($0)
            }) ?? drafts.first(where: { !isExerciseComplete($0) })

            withAnimation(.easeOut(duration: 0.22)) {
                expandedExerciseID = following?.id
            }
        }
    }

    private func prefillFromHistory() {
        for draftIndex in drafts.indices {
            guard let previous = ProgressionEngine.latestCompleted(
                for: drafts[draftIndex].template.name,
                in: history
            ) else { continue }

            let previousSets = previous.sets
            for setIndex in drafts[draftIndex].sets.indices where setIndex < previousSets.count {
                drafts[draftIndex].sets[setIndex].weight = previousSets[setIndex].weight
                drafts[draftIndex].sets[setIndex].repetitions = previousSets[setIndex].repetitions
            }
        }
    }

    private func finishWorkout() {
        let record = WorkoutRecord(
            date: startedAt,
            routineName: routine.name,
            duration: Date().timeIntervalSince(startedAt)
        )

        record.exercises = drafts.enumerated().map { exerciseIndex, draft in
            let exercise = ExerciseRecord(
                name: draft.template.name,
                assetName: draft.template.assetName,
                order: exerciseIndex
            )
            exercise.sets = draft.sets.enumerated().compactMap { setIndex, set in
                guard set.completed else { return nil }
                return SetRecord(order: setIndex, weight: set.weight, repetitions: set.repetitions)
            }
            return exercise
        }

        record.cardioEntries = cardioDrafts.enumerated().compactMap { index, draft in
            guard draft.durationMinutes > 0 else { return nil }
            return CardioRecord(
                kind: draft.kind,
                order: index,
                durationMinutes: draft.durationMinutes,
                distanceKilometers: draft.distanceKilometers,
                averageSpeed: draft.averageSpeed,
                incline: draft.kind.supportsIncline ? draft.incline : 0
            )
        }

        modelContext.insert(record)
        do {
            try modelContext.save()
            ActiveWorkoutStore.clear()
            restEnd = nil
            withAnimation(.easeOut(duration: 0.22)) {
                completedRecord = record
            }
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Nothing was lost from this active session. Try saving again."
        }
    }
}

private struct WorkoutCompletionView: View {
    let record: WorkoutRecord
    let done: () -> Void
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]

    init(record: WorkoutRecord, done: @escaping () -> Void) {
        self.record = record
        self.done = done
    }

    private var completedExercises: [ExerciseRecord] {
        record.exercises
            .filter { !$0.sets.isEmpty }
            .sorted { $0.order < $1.order }
    }

    private var completedSetCount: Int {
        completedExercises.reduce(0) { $0 + $1.sets.count }
    }

    private var cardioMinutes: Int {
        Int(record.cardioEntries.reduce(0) { $0 + $1.durationMinutes })
    }

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    Text(record.date.formatted(date: .long, time: .shortened).uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(1.5)
                        .foregroundStyle(InkPalette.softInk)

                    HStack(spacing: 0) {
                        summaryMetric(
                            "\(max(1, Int(record.duration / 60)))",
                            label: "MINUTES"
                        )
                        summaryMetric(
                            "\(completedExercises.count)",
                            label: "MOVEMENTS"
                        )
                        summaryMetric(
                            "\(completedSetCount)",
                            label: "SETS"
                        )
                    }
                    .padding(.vertical, 15)
                    .background(InkPalette.raisedPaper.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if completedExercises.isEmpty {
                        Text("No completed movements")
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(InkPalette.softInk)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 30)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("MOVEMENTS")
                                .font(.caption2.weight(.semibold))
                                .tracking(1.8)
                                .foregroundStyle(InkPalette.softInk)
                                .padding(.bottom, 8)

                            ForEach(completedExercises) { exercise in
                                completionRow(exercise)
                                if exercise.persistentModelID != completedExercises.last?.persistentModelID {
                                    InkDivider()
                                }
                            }
                        }
                    }

                    if cardioMinutes > 0 {
                        HStack {
                            Text("CARDIO")
                                .font(.caption2.weight(.semibold))
                                .tracking(1.8)
                                .foregroundStyle(InkPalette.softInk)
                            Spacer()
                            Text("\(cardioMinutes) min")
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(InkPalette.ink)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 104)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            CompletionHeader()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            InkPrimaryButton(title: "Done", action: done)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(InkPalette.paper.opacity(0.95))
        }
    }

    private func summaryMetric(_ value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(InkPalette.ink)
                .monospacedDigit()
            Text(label)
                .font(.caption2.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(InkPalette.softInk)
        }
        .frame(maxWidth: .infinity)
    }

    private func completionRow(_ exercise: ExerciseRecord) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.name)
                    .font(.system(.body, design: .serif, weight: .semibold))
                    .foregroundStyle(InkPalette.ink)
                Text(setSummary(exercise))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(InkPalette.softInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                if let comparison = comparison(for: exercise) {
                    Text(comparison)
                        .font(.system(.caption2, design: .serif, weight: .semibold))
                        .foregroundStyle(InkPalette.cinnabar)
                }
            }

            Spacer(minLength: 8)

            let records = personalRecords(for: exercise)
            if !records.isEmpty {
                VStack(alignment: .trailing, spacing: 3) {
                    ForEach(records.prefix(2)) { record in
                        Text(record.shortTitle)
                            .font(.caption2.weight(.bold))
                            .tracking(0.7)
                            .foregroundStyle(InkPalette.cinnabar)
                    }
                }
            }
        }
        .frame(minHeight: 58)
    }

    private func setSummary(_ exercise: ExerciseRecord) -> String {
        let measurement = WorkoutCatalog.exercise(named: exercise.name)?.measurement
            ?? (exercise.sets.contains { $0.weight > 0 } ? .weighted : .bodyweight)
        return exercise.sets.sorted { $0.order < $1.order }.map { set in
            switch measurement {
            case .weighted:
                let weight = set.weight.formatted(
                    .number.precision(.fractionLength(set.weight.rounded() == set.weight ? 0 : 1))
                )
                return "\(weight) × \(set.repetitions)"
            case .bodyweight:
                return "\(set.repetitions) reps"
            case .timed:
                return "\(set.repetitions) sec"
            }
        }
        .joined(separator: " · ")
    }

    private func personalRecords(for exercise: ExerciseRecord) -> [ProgressRecord] {
        let performances = ProgressionEngine.performances(for: exercise.name, in: workouts)
        guard let performance = performances.first(where: {
            $0.id == record.persistentModelID
        }) else { return [] }
        let measurement = WorkoutCatalog.exercise(named: exercise.name)?.measurement
            ?? (exercise.sets.contains { $0.weight > 0 } ? .weighted : .bodyweight)
        return ProgressionEngine.personalRecords(
            for: performance,
            measurement: measurement,
            among: performances
        )
    }

    private func comparison(for exercise: ExerciseRecord) -> String? {
        let performances = ProgressionEngine.performances(for: exercise.name, in: workouts)
        guard let performance = performances.first(where: {
            $0.id == record.persistentModelID
        }) else { return nil }
        let measurement = WorkoutCatalog.exercise(named: exercise.name)?.measurement
            ?? (exercise.sets.contains { $0.weight > 0 } ? .weighted : .bodyweight)
        return ProgressionEngine.comparison(
            for: performance,
            measurement: measurement,
            among: performances
        )
    }
}

private struct CompletionHeader: View {
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(InkPalette.cinnabar)
                    .frame(width: 9, height: 9)
                Text("SESSION COMPLETE")
                    .font(.caption.weight(.semibold))
                    .tracking(2.4)
                    .foregroundStyle(InkPalette.softInk)
                Spacer()
            }
            .frame(minHeight: 44)

            InkDivider()
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 6)
        .background {
            PaperSurface()
        }
    }
}

struct CardioLoggingSection: View {
    @Binding var entries: [CardioDraft]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CARDIO")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.8)
                    .foregroundStyle(InkPalette.softInk)
                Spacer()
                if !entries.isEmpty {
                    Text("\(Int(entries.reduce(0) { $0 + $1.durationMinutes })) MIN")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(InkPalette.softInk)
                }
            }

            ForEach($entries) { $entry in
                CardioEntryEditor(entry: $entry) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        entries.removeAll { $0.id == entry.id }
                    }
                }
            }

            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    entries.append(CardioDraft())
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text(entries.isEmpty ? "Add cardio" : "Add another cardio entry")
                }
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(InkPalette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(InkPalette.raisedPaper.opacity(0.72))
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
    }
}

struct CardioEntryEditor: View {
    @Binding var entry: CardioDraft
    let delete: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Picker("Cardio type", selection: $entry.kind) {
                    ForEach(CardioKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .tint(InkPalette.ink)
                .font(.system(.headline, design: .serif, weight: .semibold))

                Spacer()

                Button(action: delete) {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(InkPalette.cinnabar)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Delete cardio entry")
            }

            HStack(spacing: 14) {
                cardioField(
                    "MINUTES",
                    value: $entry.durationMinutes,
                    placeholder: "30"
                )
                cardioField(
                    "DISTANCE · KM",
                    value: $entry.distanceKilometers,
                    placeholder: "0"
                )
            }

            HStack(spacing: 14) {
                cardioField(
                    "SPEED · KM/H",
                    value: $entry.averageSpeed,
                    placeholder: "0"
                )

                if entry.kind.supportsIncline {
                    cardioField(
                        "INCLINE · %",
                        value: $entry.incline,
                        placeholder: "0"
                    )
                    .transition(.opacity)
                }
            }
        }
        .padding(14)
        .inkCard()
        .animation(.easeOut(duration: 0.18), value: entry.kind)
    }

    private func cardioField(
        _ label: String,
        value: Binding<Double>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .tracking(1)
                .foregroundStyle(InkPalette.softInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            TextField(
                placeholder,
                value: value,
                format: .number.precision(.fractionLength(0...2))
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.leading)
            .inkInput()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ActiveWorkoutHeader: View {
    let progress: String
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(InkPalette.cinnabar)
                    .frame(width: 9, height: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text("IN PROGRESS")
                        .font(.caption.weight(.semibold))
                        .tracking(2.6)
                        .foregroundStyle(InkPalette.softInk)
                    Text(progress)
                        .font(.system(.caption2, design: .serif))
                        .foregroundStyle(InkPalette.softInk.opacity(0.76))
                        .monospacedDigit()
                }

                Spacer()

                Button("Close", action: close)
                    .font(.system(.subheadline, design: .serif, weight: .medium))
                    .foregroundStyle(InkPalette.ink)
                    .frame(minWidth: 44, minHeight: 44)
                    .buttonStyle(PressableButtonStyle())
            }

            InkDivider()
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 6)
        .background(InkPalette.paper.opacity(0.96))
    }
}

private struct ExerciseLoggingCard: View {
    @Binding var draft: ExerciseDraft
    let previous: ExercisePerformance?
    let recommendation: ProgressionRecommendation?
    let isExpanded: Bool
    let toggleExpanded: () -> Void
    let didUpdateSet: (Bool) -> Void

    private var completedSetCount: Int {
        draft.sets.filter(\.completed).count
    }

    private var isComplete: Bool {
        completedSetCount >= draft.template.sets
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: toggleExpanded) {
                HStack(spacing: 14) {
                    DemonstrationImage(assetName: draft.template.assetName)
                        .frame(
                            width: isExpanded ? 86 : 64,
                            height: isExpanded ? 86 : 64
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(draft.template.name)
                            .font(.system(.headline, design: .serif, weight: .semibold))
                            .foregroundStyle(InkPalette.ink)
                            .multilineTextAlignment(.leading)
                        Text(draft.template.targetText)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(InkPalette.softInk)
                        Text(statusText)
                            .font(.caption2.weight(.semibold))
                            .tracking(1)
                            .foregroundStyle(isComplete ? InkPalette.cinnabar : InkPalette.softInk)
                            .monospacedDigit()
                    }
                    Spacer(minLength: 0)

                    Text(isExpanded ? "CLOSE" : "VIEW")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.1)
                        .foregroundStyle(InkPalette.softInk.opacity(0.72))
                        .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                }
                .padding(isExpanded ? 11 : 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .animation(.easeOut(duration: 0.2), value: isExpanded)

            if isExpanded {
                Group {
                    if let previous {
                        LastPerformanceSummary(
                            template: draft.template,
                            performance: previous,
                            recommendation: recommendation
                        )
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                    }

                    InkDivider()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)

                    HStack {
                        Text("SET")
                            .frame(width: 36, alignment: .leading)
                        Text(draft.template.measurement == .weighted ? draft.template.loadLabel : "LOAD")
                            .frame(maxWidth: .infinity)
                        Text(draft.template.measurement == .timed ? "SEC" : "REPS")
                            .frame(maxWidth: .infinity)
                        Color.clear.frame(width: 44, height: 1)
                    }
                    .font(.caption2.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(InkPalette.softInk)
                    .padding(.horizontal, 14)
                    .padding(.top, 6)

                    ForEach(Array(draft.sets.indices), id: \.self) { index in
                        SetLoggingRow(
                            index: index + 1,
                            measurement: draft.template.measurement,
                            set: $draft.sets[index],
                            didToggleCompletion: didUpdateSet
                        )
                    }
                    .padding(.horizontal, 10)

                    Button {
                        draft.sets.append(
                            SetDraft(
                                weight: draft.sets.last?.weight ?? 0,
                                repetitions: draft.sets.last?.repetitions ?? draft.template.minimumRepetitions
                            )
                        )
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Add another set")
                        }
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .foregroundStyle(InkPalette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.horizontal, 10)
                    .padding(.bottom, 9)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .inkCard()
    }

    private var statusText: String {
        if isComplete {
            return "DONE · \(completedSetCount) SETS"
        }
        return "\(completedSetCount)/\(draft.template.sets) SETS"
    }
}

private struct LastPerformanceSummary: View {
    let template: ExerciseTemplate
    let performance: ExercisePerformance
    let recommendation: ProgressionRecommendation?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("LAST · \(performance.date.formatted(.dateTime.day().month(.abbreviated)).uppercased())")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(InkPalette.softInk)
                Spacer()
                if let recommendation {
                    Text(recommendation.title.uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(1.1)
                        .foregroundStyle(InkPalette.cinnabar)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }

            Text(setSummary)
                .font(.caption.monospacedDigit())
                .foregroundStyle(InkPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .accessibilityElement(children: .combine)
    }

    private var setSummary: String {
        performance.sets.map { set in
            switch template.measurement {
            case .weighted:
                "\(weightText(set.weight)) × \(set.repetitions)"
            case .bodyweight:
                "\(set.repetitions) reps"
            case .timed:
                "\(set.repetitions) sec"
            }
        }
        .joined(separator: "  ·  ")
    }

    private func weightText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(value.rounded() == value ? 0 : 1)))
    }
}

private struct SetLoggingRow: View {
    let index: Int
    let measurement: ExerciseTemplate.Measurement
    @Binding var set: SetDraft
    let didToggleCompletion: (Bool) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index)")
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(InkPalette.softInk)
                .frame(width: 36, alignment: .leading)

            if measurement == .weighted {
                TextField("0", value: $set.weight, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .inkInput()
            } else {
                Text("BODY")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(InkPalette.softInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(InkPalette.paper.opacity(0.45))
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(InkPalette.ink.opacity(0.28))
                            .frame(height: 1)
                    }
            }

            TextField("0", value: $set.repetitions, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .inkInput()

            Button {
                set.completed.toggle()
                didToggleCompletion(set.completed)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(InkPalette.ink.opacity(set.completed ? 0 : 0.28), lineWidth: 1)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(set.completed ? InkPalette.cinnabar : .clear)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(InkPalette.paper)
                        .scaleEffect(set.completed ? 1 : 0.25)
                        .opacity(set.completed ? 1 : 0)
                        .blur(radius: set.completed ? 0 : 4)
                }
                .frame(width: 42, height: 42)
                .animation(.easeOut(duration: 0.2), value: set.completed)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(set.completed ? "Mark incomplete" : "Mark complete")
        }
        .padding(.vertical, 5)
    }
}

struct InkInput: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body.monospacedDigit().weight(.medium))
            .foregroundStyle(InkPalette.ink)
            .frame(height: 42)
            .background(InkPalette.paper.opacity(0.45))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(InkPalette.ink.opacity(0.28))
                    .frame(height: 1)
            }
    }
}

extension View {
    func inkInput() -> some View {
        modifier(InkInput())
    }
}

private struct RestTimer: View {
    let end: Date
    let cancel: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(end.timeIntervalSince(context.date).rounded(.up)))
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("REST")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.8)
                        .foregroundStyle(InkPalette.softInk)
                    Text(timeString(remaining))
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .foregroundStyle(InkPalette.ink)
                }
                Spacer()
                Button("Skip", action: cancel)
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .foregroundStyle(InkPalette.ink)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, 16)
            .frame(height: 64)
            .inkCard()
            .onChange(of: remaining) { _, value in
                if value == 0 { cancel() }
            }
        }
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
