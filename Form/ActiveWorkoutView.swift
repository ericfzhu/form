import SwiftUI
import SwiftData
import UIKit

private struct SetDraft: Identifiable {
    let id = UUID()
    var weight: Double
    var repetitions: Int
    var completed = false
    var kind: SetKind = .working
}

private struct ExerciseDraft: Identifiable {
    let id: String
    let template: ExerciseTemplate
    var sets: [SetDraft]
}

private struct WorkoutInputField: Hashable {
    enum Value: Hashable {
        case load
        case repetitions
    }

    let exerciseID: String
    let setID: UUID
    let value: Value
}

private struct WorkoutLiveState: Equatable {
    let completedMovements: Int
    let totalMovements: Int
    let currentExercise: String
    let restEnd: Date?
}

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var history: [WorkoutRecord]
    @AppStorage("keep-screen-awake") private var keepScreenAwake = true
    @AppStorage("progression-load-increment") private var loadIncrement = 2.5

    let routine: RoutineTemplate
    let onDone: () -> Void
    let resumedFromSnapshot: Bool
    @State private var startedAt = Date()
    @State private var activeDuration: TimeInterval
    @State private var activeSegmentStartedAt: Date?
    @State private var drafts: [ExerciseDraft]
    @State private var cardioDrafts: [CardioDraft] = []
    @State private var restEnd: Date?
    @State private var showingCancelConfirmation = false
    @State private var showingEmptyFinishConfirmation = false
    @State private var showingIncompleteFinishConfirmation = false
    @State private var expandedExerciseID: String?
    @State private var completedRecord: WorkoutRecord?
    @State private var healthSyncState: HealthWorkoutSyncState = .notConnected
    @State private var saveErrorMessage: String?
    @State private var isKeyboardVisible = false
    @State private var didEndSession = false
    @FocusState private var focusedInput: WorkoutInputField?

    init(
        routine: RoutineTemplate,
        snapshot: ActiveWorkoutSnapshot? = nil,
        onDone: @escaping () -> Void = {}
    ) {
        self.routine = routine
        self.onDone = onDone
        let validSnapshot = snapshot?.routineID == routine.id ? snapshot : nil
        resumedFromSnapshot = validSnapshot != nil
        let now = Date()
        _startedAt = State(initialValue: validSnapshot?.startedAt ?? now)
        _activeDuration = State(initialValue: max(0, validSnapshot?.activeDuration ?? 0))
        _activeSegmentStartedAt = State(initialValue: now)
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
                        completed: $0.completed,
                        kind: $0.kind ?? .working
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
        _restEnd = State(
            initialValue: validSnapshot?.restEnd.flatMap { $0 > Date() ? $0 : nil }
        )
    }

    var body: some View {
        Group {
            if let completedRecord {
                WorkoutCompletionView(
                    record: completedRecord,
                    healthSyncState: healthSyncState
                ) {
                    onDone()
                    dismiss()
                }
            } else {
                workoutLogger
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Group {
                if completedRecord == nil {
                    ActiveWorkoutHeader(
                        index: routine.id,
                        progress: "\(completedMovementCount) of \(drafts.count) movements",
                        close: saveAndClose,
                        requestDiscard: { showingCancelConfirmation = true }
                    )
                } else {
                    CompletionHeader()
                }
            }
            .transaction { transaction in
                transaction.animation = nil
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Discard this session?", isPresented: $showingCancelConfirmation) {
            Button("Discard session", role: .destructive, action: discardWorkout)
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
        .confirmationDialog(
            "Finish this partial session?",
            isPresented: $showingIncompleteFinishConfirmation
        ) {
            Button("Finish partial session", role: .destructive, action: finishWorkout)
            Button("Keep training", role: .cancel) {}
        } message: {
            Text("\(completedMovementCount) of \(drafts.count) movements are complete. Only completed sets and cardio entries will be saved.")
        }
        .leadingEdgeSwipe {
            if completedRecord == nil {
                saveAndClose()
            }
        }
        .alert("Couldn’t save session", isPresented: Binding(
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
            updateScreenAwakeState()
            persistDraft()
            syncLiveActivity(startIfNeeded: true)
        }
        .onChange(of: currentSnapshot) { _, _ in
            persistDraft()
        }
        .onChange(of: liveActivityState) { _, _ in
            syncLiveActivity()
        }
        .onChange(of: keepScreenAwake) { _, _ in
            updateScreenAwakeState()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            if !didEndSession && completedRecord == nil {
                pauseActiveDuration()
                persistDraft()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
        ) { _ in
            isKeyboardVisible = true
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
        ) { _ in
            isKeyboardVisible = false
        }
    }

    private var workoutLogger: some View {
        ZStack {
            PaperBackground()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach($drafts) { $draft in
                            ExerciseLoggingCard(
                                draft: $draft,
                                previous: ProgressionEngine.latestCompleted(
                                    for: draft.template,
                                    in: history
                                ),
                                recommendation: ProgressionEngine.recommendation(
                                    for: draft.template,
                                    performances: ProgressionEngine.performances(
                                        for: draft.template,
                                        in: history
                                    )
                                ),
                                isExpanded: expandedExerciseID == draft.id,
                                focusedInput: $focusedInput,
                                toggleExpanded: {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        expandedExerciseID = expandedExerciseID == draft.id
                                            ? nil
                                            : draft.id
                                    }
                                },
                                didUpdateSet: { completed, kind in
                                    didUpdateSet(
                                        for: draft.id,
                                        completed: completed,
                                        kind: kind
                                    )
                                }
                            )
                            .id(draft.id)
                        }

                        CardioLoggingSection(entries: $cardioDrafts)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 14)
                    .padding(.bottom, restEnd == nil ? 96 : 158)
                }
                .onChange(of: expandedExerciseID) { oldValue, newValue in
                    guard oldValue != nil, let newValue else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        withAnimation(.easeOut(duration: 0.24)) {
                            proxy.scrollTo(newValue, anchor: .top)
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Group {
                if isKeyboardVisible {
                    HStack(spacing: 2) {
                        Button {
                            moveInputFocus(by: -1)
                        } label: {
                            Image(systemName: "chevron.up")
                                .frame(width: 44, height: 44)
                        }
                        .disabled(!canMoveInputFocus(by: -1))
                        .accessibilityLabel("Previous field")

                        Button {
                            moveInputFocus(by: 1)
                        } label: {
                            Image(systemName: "chevron.down")
                                .frame(width: 44, height: 44)
                        }
                        .disabled(!canMoveInputFocus(by: 1))
                        .accessibilityLabel("Next field")

                        Spacer(minLength: 8)

                        Button {
                            adjustFocusedInput(by: -1)
                        } label: {
                            Image(systemName: "minus")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Decrease value")

                        Button {
                            adjustFocusedInput(by: 1)
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Increase value")

                        Button("Done") {
                            dismissKeyboard()
                            focusedInput = nil
                        }
                        .font(.system(.body, design: .serif, weight: .semibold))
                        .foregroundStyle(InkPalette.cinnabar)
                        .frame(minWidth: 64, minHeight: 44, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(PaperSurface())
                } else {
                    VStack(spacing: 9) {
                        if let restEnd {
                            RestTimer(
                                end: restEnd,
                                adjust: adjustRest,
                                cancel: { self.restEnd = nil }
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        InkPrimaryButton(title: "Finish session", action: requestFinish)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(InkPalette.paper)
                    .overlay(alignment: .top) {
                        Rectangle().fill(InkPalette.ink).frame(height: 1)
                    }
                }
            }
            .animation(.easeOut(duration: 0.16), value: isKeyboardVisible)
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

    private var inputFields: [WorkoutInputField] {
        drafts.flatMap { draft in
            draft.sets.flatMap { set -> [WorkoutInputField] in
                var fields: [WorkoutInputField] = []
                if draft.template.recordsLoad {
                    fields.append(
                        WorkoutInputField(
                            exerciseID: draft.id,
                            setID: set.id,
                            value: .load
                        )
                    )
                }
                fields.append(
                    WorkoutInputField(
                        exerciseID: draft.id,
                        setID: set.id,
                        value: .repetitions
                    )
                )
                return fields
            }
        }
    }

    private func canMoveInputFocus(by offset: Int) -> Bool {
        guard let focusedInput,
              let index = inputFields.firstIndex(of: focusedInput) else { return false }
        return inputFields.indices.contains(index + offset)
    }

    private func moveInputFocus(by offset: Int) {
        guard let focusedInput,
              let index = inputFields.firstIndex(of: focusedInput),
              inputFields.indices.contains(index + offset) else { return }
        self.focusedInput = inputFields[index + offset]
    }

    private func adjustFocusedInput(by direction: Double) {
        guard let focusedInput,
              let exerciseIndex = drafts.firstIndex(where: {
                  $0.id == focusedInput.exerciseID
              }),
              let setIndex = drafts[exerciseIndex].sets.firstIndex(where: {
                  $0.id == focusedInput.setID
              }) else { return }

        switch focusedInput.value {
        case .load:
            drafts[exerciseIndex].sets[setIndex].weight = max(
                0,
                drafts[exerciseIndex].sets[setIndex].weight
                    + direction * loadIncrement
            )
        case .repetitions:
            drafts[exerciseIndex].sets[setIndex].repetitions = max(
                0,
                drafts[exerciseIndex].sets[setIndex].repetitions + Int(direction)
            )
        }
    }

    private func adjustRest(by seconds: Int) {
        guard let restEnd else { return }
        let adjusted = restEnd.addingTimeInterval(TimeInterval(seconds))
        self.restEnd = adjusted > Date() ? adjusted : nil
    }

    private func requestFinish() {
        if !hasRecordedWork {
            showingEmptyFinishConfirmation = true
        } else if completedMovementCount < drafts.count {
            showingIncompleteFinishConfirmation = true
        } else {
            finishWorkout()
        }
    }

    private var elapsedActiveDuration: TimeInterval {
        activeDuration + (activeSegmentStartedAt.map {
            max(0, Date().timeIntervalSince($0))
        } ?? 0)
    }

    private var currentSnapshot: ActiveWorkoutSnapshot {
        ActiveWorkoutSnapshot(
            routineID: routine.id,
            startedAt: startedAt,
            activeDuration: elapsedActiveDuration,
            exercises: drafts.map { draft in
                ActiveExerciseSnapshot(
                    exerciseID: draft.id,
                    sets: draft.sets.map {
                        ActiveSetSnapshot(
                            weight: $0.weight,
                            repetitions: $0.repetitions,
                            completed: $0.completed,
                            kind: $0.kind
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
            expandedExerciseID: expandedExerciseID,
            restEnd: restEnd
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
        didEndSession = true
        ActiveWorkoutStore.clear()
        UIApplication.shared.isIdleTimerDisabled = false
        Task { await WorkoutLiveActivityController.end() }
        dismiss()
    }

    private func saveAndClose() {
        pauseActiveDuration()
        persistDraft()
        UIApplication.shared.isIdleTimerDisabled = false
        Task { await WorkoutLiveActivityController.end() }
        dismiss()
    }

    private func pauseActiveDuration() {
        guard let activeSegmentStartedAt else { return }
        activeDuration += max(0, Date().timeIntervalSince(activeSegmentStartedAt))
        self.activeSegmentStartedAt = nil
    }

    private func isExerciseComplete(_ draft: ExerciseDraft) -> Bool {
        draft.sets.filter { $0.completed && $0.kind == .working }.count >= draft.template.sets
    }

    private func didUpdateSet(
        for exerciseID: String,
        completed: Bool,
        kind: SetKind
    ) {
        guard completed,
              let index = drafts.firstIndex(where: { $0.id == exerciseID }) else { return }
        let prescribedRest = drafts[index].template.restSeconds
        let restSeconds = kind == .warmup ? min(90, prescribedRest) : prescribedRest
        restEnd = Date().addingTimeInterval(
            TimeInterval(restSeconds)
        )

        DispatchQueue.main.async {
            guard isExerciseComplete(drafts[index]) else { return }

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
                for: drafts[draftIndex].template,
                in: history
            ) else { continue }

            let previousSets = previous.sets
            let workingIndices = drafts[draftIndex].sets.indices.filter {
                drafts[draftIndex].sets[$0].kind == .working
            }
            for (setIndex, previousSet) in zip(workingIndices, previousSets) {
                drafts[draftIndex].sets[setIndex].weight = previousSet.weight
                drafts[draftIndex].sets[setIndex].repetitions = previousSet.repetitions
            }
        }
    }

    private func finishWorkout() {
        let record = WorkoutRecord(
            date: startedAt,
            routineName: routine.name,
            duration: elapsedActiveDuration
        )

        record.exercises = drafts.enumerated().map { exerciseIndex, draft in
            let exercise = ExerciseRecord(
                exerciseID: draft.template.id,
                name: draft.template.name,
                assetName: draft.template.assetName,
                order: exerciseIndex
            )
            exercise.sets = draft.sets.enumerated().compactMap { setIndex, set in
                guard set.completed else { return nil }
                return SetRecord(
                    order: setIndex,
                    weight: set.weight,
                    repetitions: set.repetitions,
                    kind: set.kind
                )
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
            didEndSession = true
            ActiveWorkoutStore.clear()
            restEnd = nil
            UIApplication.shared.isIdleTimerDisabled = false
            Task { await WorkoutLiveActivityController.end() }
            withAnimation(.easeOut(duration: 0.22)) {
                completedRecord = record
            }
            syncCompletedWorkout(record)
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Nothing was lost from this active session. Try saving again."
        }
    }

    private func syncCompletedWorkout(_ record: WorkoutRecord) {
        let health = HealthKitService.shared
        guard health.canWriteWorkouts else {
            healthSyncState = .notConnected
            return
        }

        healthSyncState = .syncing
        Task {
            do {
                record.healthKitWorkoutUUID = try await health.saveWorkout(from: record)
                try modelContext.save()
                healthSyncState = .saved
            } catch {
                healthSyncState = .failed
            }
        }
    }

    private var currentExerciseName: String {
        if let expandedExerciseID,
           let expanded = drafts.first(where: { $0.id == expandedExerciseID }) {
            return expanded.template.name
        }
        return drafts.first(where: { !isExerciseComplete($0) })?.template.name
            ?? routine.name
    }

    private var liveActivityState: WorkoutLiveState {
        WorkoutLiveState(
            completedMovements: completedMovementCount,
            totalMovements: drafts.count,
            currentExercise: currentExerciseName,
            restEnd: restEnd
        )
    }

    private func updateScreenAwakeState() {
        UIApplication.shared.isIdleTimerDisabled = keepScreenAwake && completedRecord == nil
    }

    private func syncLiveActivity(startIfNeeded: Bool = false) {
        let completed = completedMovementCount
        let total = drafts.count
        let exercise = currentExerciseName
        let activeRestEnd = restEnd
        let routineName = routine.name
        let sessionStart = Date().addingTimeInterval(-elapsedActiveDuration)

        Task {
            if startIfNeeded {
                await WorkoutLiveActivityController.begin(
                    routineName: routineName,
                    startedAt: sessionStart,
                    completedMovements: completed,
                    totalMovements: total,
                    currentExercise: exercise,
                    restEnd: activeRestEnd
                )
            } else {
                await WorkoutLiveActivityController.update(
                    completedMovements: completed,
                    totalMovements: total,
                    currentExercise: exercise,
                    restEnd: activeRestEnd
                )
            }
        }
    }
}

private struct WorkoutCompletionView: View {
    let record: WorkoutRecord
    let healthSyncState: HealthWorkoutSyncState
    let done: () -> Void
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]

    init(
        record: WorkoutRecord,
        healthSyncState: HealthWorkoutSyncState,
        done: @escaping () -> Void
    ) {
        self.record = record
        self.healthSyncState = healthSyncState
        self.done = done
    }

    private var completedExercises: [ExerciseRecord] {
        record.exercises
            .filter { exercise in exercise.sets.contains { $0.kind == .working } }
            .sorted { $0.order < $1.order }
    }

    private var completedSetCount: Int {
        completedExercises.reduce(0) {
            $0 + $1.sets.filter { $0.kind == .working }.count
        }
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
                    .background(InkPalette.raisedPaper)
                    .overlay { Rectangle().stroke(InkPalette.ink, lineWidth: 1) }

                    if let healthStatusText {
                        HStack(spacing: 10) {
                            Image(systemName: healthSyncState == .saved
                                  ? "heart.fill"
                                  : "heart")
                                .foregroundStyle(InkPalette.cinnabar)
                            Text(healthStatusText)
                                .font(.system(.caption, design: .serif, weight: .semibold))
                                .foregroundStyle(
                                    healthSyncState == .failed
                                        ? InkPalette.cinnabar
                                        : InkPalette.softInk
                                )
                            Spacer()
                        }
                    }

                    if completedExercises.isEmpty {
                        Text("No movements recorded")
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            InkPrimaryButton(title: "Done", action: done)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(InkPalette.paper.opacity(0.95))
        }
    }

    private var healthStatusText: String? {
        switch healthSyncState {
        case .notConnected:
            return nil
        case .syncing:
            return "Saving to Apple Health"
        case .saved:
            return "Saved to Apple Health"
        case .failed:
            return "Not saved to Apple Health"
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
        let measurement = WorkoutCatalog.exercise(for: exercise)?.measurement
            ?? (exercise.sets.contains { $0.weight > 0 } ? .weighted : .bodyweight)
        return exercise.sets.sorted { $0.order < $1.order }.map { set in
            let prefix = set.kind == .warmup ? "W " : ""
            switch measurement {
            case .weighted:
                let weight = set.weight.formatted(
                    .number.precision(.fractionLength(set.weight.rounded() == set.weight ? 0 : 1))
                )
                return "\(prefix)\(weight) × \(set.repetitions)"
            case .weightedTimed:
                let weight = set.weight.formatted(
                    .number.precision(.fractionLength(set.weight.rounded() == set.weight ? 0 : 1))
                )
                return "\(prefix)\(weight) kg / hand × \(set.repetitions) sec"
            case .bodyweight:
                return "\(prefix)\(set.repetitions) reps"
            case .timed:
                return "\(prefix)\(set.repetitions) sec"
            }
        }
        .joined(separator: " · ")
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

private struct CompletionHeader: View {
    var body: some View {
        HStack(spacing: 10) {
                Text("✓")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(InkPalette.raisedPaper)
                    .frame(width: 52, height: 52)
                    .background {
                        Rectangle()
                            .fill(InkPalette.cinnabar)
                    }
                Text("SESSION COMPLETE")
                    .font(.system(.caption, design: .serif, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(InkPalette.ink)
                Spacer()
        }
        .padding(.trailing, 16)
        .background { PaperSurface() }
        .overlay(alignment: .bottom) { ClassicalRule() }
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
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(InkPalette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(InkPalette.raisedPaper)
                .overlay { Rectangle().stroke(InkPalette.bronze.opacity(0.62), lineWidth: 1) }
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
    let index: String
    let progress: String
    let close: () -> Void
    let requestDiscard: () -> Void

    var body: some View {
        HStack(spacing: 0) {
                Text(index)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundStyle(InkPalette.cinnabar)
                    .frame(width: 52, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("SESSION IN PROGRESS")
                        .font(.system(.caption, design: .serif, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(InkPalette.ink)
                    Text(progress)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(InkPalette.softInk.opacity(0.76))
                        .monospacedDigit()
                }
                .padding(.leading, 12)

                Spacer()

                Button("Close", action: close)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(InkPalette.ink)
                    .frame(width: 58, height: 56)
                    .buttonStyle(PressableButtonStyle())

                Menu {
                    Button("Discard session", role: .destructive, action: requestDiscard)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(InkPalette.ink)
                        .frame(width: 44, height: 56)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Session options")
        }
        .background(InkPalette.paper)
        .overlay(alignment: .top) { InkDivider() }
        .overlay(alignment: .bottom) { ClassicalRule() }
    }
}

private struct ExerciseLoggingCard: View {
    @Binding var draft: ExerciseDraft
    let previous: ExercisePerformance?
    let recommendation: ProgressionRecommendation?
    let isExpanded: Bool
    @FocusState.Binding var focusedInput: WorkoutInputField?
    let toggleExpanded: () -> Void
    let didUpdateSet: (Bool, SetKind) -> Void

    private var completedSetCount: Int {
        draft.sets.filter { $0.completed && $0.kind == .working }.count
    }

    private var isComplete: Bool {
        completedSetCount >= draft.template.sets
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: toggleExpanded) {
                HStack(spacing: 14) {
                    DemonstrationImage(assetName: draft.template.assetName)
                        .frame(width: 64, height: 64)

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

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(InkPalette.softInk.opacity(0.72))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                        .accessibilityHidden(true)
                }
                .padding(8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint(isExpanded ? "Hides exercise details" : "Shows exercise details")

            if isExpanded {
                VStack(spacing: 0) {
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
                        Text("TYPE")
                            .frame(width: 40, alignment: .leading)
                        Text(draft.template.recordsLoad ? draft.template.loadLabel : "LOAD")
                            .frame(maxWidth: .infinity)
                        Text(draft.template.recordsTime ? "SEC" : "REPS")
                            .frame(maxWidth: .infinity)
                        Color.clear.frame(width: 52, height: 1)
                    }
                    .font(.caption2.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(InkPalette.softInk)
                    .padding(.horizontal, 14)
                    .padding(.top, 6)

                    ForEach($draft.sets) { $set in
                        SetLoggingRow(
                            exerciseID: draft.id,
                            index: setNumber(for: set.id),
                            measurement: draft.template.measurement,
                            set: $set,
                            focusedInput: $focusedInput,
                            canDelete: draft.sets.count > draft.template.sets
                                || set.kind == .warmup,
                            delete: {
                                focusedInput = nil
                                withAnimation(.easeOut(duration: 0.18)) {
                                    draft.sets.removeAll { $0.id == set.id }
                                }
                            },
                            didToggleCompletion: didUpdateSet
                        )
                    }
                    .padding(.horizontal, 10)

                    Button(action: applyFirstWorkingSetToRemaining) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc")
                            Text("Apply first set to remaining")
                        }
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(0.7)
                        .textCase(.uppercase)
                        .foregroundStyle(InkPalette.cinnabar)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .overlay { Rectangle().stroke(InkPalette.cinnabar, lineWidth: 1) }
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(!canApplyFirstWorkingSet)
                    .opacity(canApplyFirstWorkingSet ? 1 : 0.4)
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
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.7)
                        .textCase(.uppercase)
                        .foregroundStyle(InkPalette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(InkPalette.raisedPaper)
                        .overlay { Rectangle().stroke(InkPalette.bronze.opacity(0.62), lineWidth: 1) }
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.horizontal, 10)

                    Button {
                        let firstWorkingIndex = draft.sets.firstIndex { $0.kind == .working } ?? 0
                        let reference = draft.sets.indices.contains(firstWorkingIndex)
                            ? draft.sets[firstWorkingIndex]
                            : SetDraft(weight: 0, repetitions: draft.template.minimumRepetitions)
                        draft.sets.insert(
                            SetDraft(
                                weight: reference.weight,
                                repetitions: reference.repetitions,
                                kind: .warmup
                            ),
                            at: firstWorkingIndex
                        )
                    } label: {
                        Text("Add warm-up set")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.7)
                            .textCase(.uppercase)
                            .foregroundStyle(InkPalette.cinnabar)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .overlay { Rectangle().stroke(InkPalette.cinnabar, lineWidth: 1) }
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.horizontal, 10)
                    .padding(.bottom, 9)
                }
                .clipped()
                .transition(.downwardReveal)
            }
        }
        .inkCard()
    }

    private func setNumber(for id: UUID) -> Int {
        guard let index = draft.sets.firstIndex(where: { $0.id == id }) else { return 1 }
        return draft.sets.prefix(index + 1).filter { $0.kind == .working }.count
    }

    private var canApplyFirstWorkingSet: Bool {
        guard let firstIndex = draft.sets.firstIndex(where: { $0.kind == .working }) else {
            return false
        }
        return draft.sets.indices.contains(where: { index in
            index > firstIndex
                && draft.sets[index].kind == .working
                && !draft.sets[index].completed
        })
    }

    private func applyFirstWorkingSetToRemaining() {
        guard let firstIndex = draft.sets.firstIndex(where: { $0.kind == .working }) else {
            return
        }
        let reference = draft.sets[firstIndex]
        for index in draft.sets.indices where index > firstIndex
            && draft.sets[index].kind == .working
            && !draft.sets[index].completed {
            draft.sets[index].weight = reference.weight
            draft.sets[index].repetitions = reference.repetitions
        }
    }

    private var statusText: String {
        if isComplete {
            return "DONE · \(completedSetCount) SETS"
        }
        return "\(completedSetCount)/\(draft.template.sets) SETS"
    }
}

private struct DownwardRevealModifier: AnimatableModifier {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .offset(y: -8 * (1 - progress))
            .mask(alignment: .top) {
                Rectangle()
                    .scaleEffect(y: progress, anchor: .top)
            }
    }
}

private extension AnyTransition {
    static let downwardReveal = AnyTransition.modifier(
        active: DownwardRevealModifier(progress: 0),
        identity: DownwardRevealModifier(progress: 1)
    )
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
            case .weightedTimed:
                "\(weightText(set.weight)) kg / hand × \(set.repetitions) sec"
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
    let exerciseID: String
    let index: Int
    let measurement: ExerciseTemplate.Measurement
    @Binding var set: SetDraft
    @FocusState.Binding var focusedInput: WorkoutInputField?
    let canDelete: Bool
    let delete: () -> Void
    let didToggleCompletion: (Bool, SetKind) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(SetKind.allCases) { kind in
                    Button {
                        set.kind = kind
                    } label: {
                        if set.kind == kind {
                            Label(kind.title, systemImage: "checkmark")
                        } else {
                            Text(kind.title)
                        }
                    }
                }
                if canDelete {
                    Divider()
                    Button("Delete set", role: .destructive, action: delete)
                }
            } label: {
                HStack(spacing: 2) {
                    Text(set.kind == .warmup ? set.kind.shortTitle : "\(index)")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                }
                .font(.system(.body, design: .serif, weight: .semibold))
                .foregroundStyle(set.kind == .warmup ? InkPalette.raisedPaper : InkPalette.cinnabar)
                .frame(width: 40, height: 44)
                .background(set.kind == .warmup ? InkPalette.cinnabar : InkPalette.raisedPaper)
                .overlay { Rectangle().stroke(InkPalette.bronze.opacity(0.72), lineWidth: 1) }
                .contentShape(Rectangle())
            }
            .tint(InkPalette.ink)
            .accessibilityLabel("Set type: \(set.kind.title)")

            if measurement == .weighted || measurement == .weightedTimed {
                TextField("0", value: $set.weight, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .inkInput()
                    .focused(
                        $focusedInput,
                        equals: WorkoutInputField(
                            exerciseID: exerciseID,
                            setID: set.id,
                            value: .load
                        )
                    )
            } else {
                    Text("BODY")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(InkPalette.softInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(InkPalette.raisedPaper)
                    .overlay { Rectangle().stroke(InkPalette.bronze.opacity(0.62), lineWidth: 1) }
            }

            TextField("0", value: $set.repetitions, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .inkInput()
                .focused(
                    $focusedInput,
                    equals: WorkoutInputField(
                        exerciseID: exerciseID,
                        setID: set.id,
                        value: .repetitions
                    )
                )

            Button {
                set.completed.toggle()
                let completed = set.completed
                dismissKeyboard()
                didToggleCompletion(completed, set.kind)
            } label: {
                ZStack {
                    Rectangle()
                        .stroke(InkPalette.ink.opacity(set.completed ? 0 : 0.28), lineWidth: 1)
                    Rectangle()
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
                .frame(width: 52, height: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(set.completed ? "Mark incomplete" : "Mark complete")
        }
        .padding(.vertical, 2)
        .overlay(alignment: .bottom) {
            Rectangle().fill(InkPalette.ink.opacity(0.18)).frame(height: 1)
        }
    }
}

struct InkInput: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body.monospacedDigit().weight(.medium))
            .foregroundStyle(InkPalette.ink)
            .frame(height: 42)
            .background(InkPalette.raisedPaper)
            .overlay { Rectangle().stroke(InkPalette.bronze.opacity(0.62), lineWidth: 1) }
    }
}

extension View {
    func inkInput() -> some View {
        modifier(InkInput())
    }
}

private struct RestTimer: View {
    let end: Date
    let adjust: (Int) -> Void
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

                Button("−30") {
                    adjust(-30)
                }
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(InkPalette.ink)
                .frame(width: 44, height: 44)
                .accessibilityLabel("Subtract 30 seconds")

                Button("+30") {
                    adjust(30)
                }
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(InkPalette.ink)
                .frame(width: 44, height: 44)
                .accessibilityLabel("Add 30 seconds")

                Button("Skip", action: cancel)
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .foregroundStyle(InkPalette.ink)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, 16)
            .frame(height: 64)
            .background(InkPalette.raisedPaper)
            .overlay { Rectangle().stroke(InkPalette.bronze.opacity(0.72), lineWidth: 1) }
            .overlay(alignment: .top) { Rectangle().fill(InkPalette.cinnabar).frame(height: 2) }
            .onChange(of: remaining) { _, value in
                if value == 0 { cancel() }
            }
        }
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
