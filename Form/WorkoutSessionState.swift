import Foundation
import Observation

struct SetDraft: Identifiable {
    let id: UUID
    var weight: Double
    var repetitions: Int
    var completed: Bool
    var kind: SetKind
    var initialWeight: Double
    var initialRepetitions: Int

    var hasUnrecordedChanges: Bool {
        !completed && (weight != initialWeight || repetitions != initialRepetitions)
    }

    init(
        id: UUID = UUID(),
        weight: Double,
        repetitions: Int,
        completed: Bool = false,
        kind: SetKind = .working,
        initialWeight: Double? = nil,
        initialRepetitions: Int? = nil
    ) {
        self.id = id
        self.weight = weight
        self.repetitions = repetitions
        self.completed = completed
        self.kind = kind
        self.initialWeight = initialWeight ?? weight
        self.initialRepetitions = initialRepetitions ?? repetitions
    }
}

struct ExerciseDraft: Identifiable {
    let id: String
    let template: ExerciseTemplate
    var sets: [SetDraft]
}

@MainActor
@Observable
final class WorkoutSessionState {
    let sessionID: UUID
    let routine: RoutineTemplate
    let resumedFromSnapshot: Bool
    let startedAt: Date

    var drafts: [ExerciseDraft]
    var cardioDrafts: [CardioDraft]
    var timedWalk: TimedWalk?
    var restEnd: Date?
    var expandedExerciseID: String?
    var restSourceSetID: UUID?
    var entryTexts: [String: String]
    var isCardioExpanded: Bool
    var selectedSetIDs: [String: UUID]

    private var duration: ActiveDurationAccumulator

    init(
        routine: RoutineTemplate,
        snapshot: ActiveWorkoutSnapshot? = nil,
        now: Date = Date()
    ) {
        self.routine = routine
        let validSnapshot = snapshot?.routineID == routine.id ? snapshot : nil
        resumedFromSnapshot = validSnapshot != nil
        sessionID = validSnapshot?.sessionID ?? UUID()
        startedAt = validSnapshot?.startedAt ?? now
        duration = ActiveDurationAccumulator(
            accumulated: validSnapshot?.sessionTimerStartedAt == nil ? max(0, validSnapshot?.activeDuration ?? 0) : 0,
            segmentStartedAt: validSnapshot?.sessionTimerStartedAt ?? now
        )
        drafts = routine.exercises.map { exercise in
            let savedSets = validSnapshot?.exercises
                .first { $0.exerciseID == exercise.id }?.sets
            return ExerciseDraft(
                id: exercise.id,
                template: exercise,
                sets: savedSets?.map {
                    SetDraft(
                        id: $0.id ?? UUID(),
                        weight: $0.weight,
                        repetitions: $0.repetitions,
                        completed: $0.completed,
                        kind: $0.kind ?? .working,
                        initialWeight: $0.initialWeight,
                        initialRepetitions: $0.initialRepetitions
                    )
                } ?? (0..<exercise.sets).map { _ in
                    SetDraft(
                        weight: 0,
                        repetitions: exercise.minimumRepetitions
                    )
                }
            )
        }
        cardioDrafts = validSnapshot?.cardio.map {
            CardioDraft(
                id: $0.id,
                kind: $0.kind,
                durationMinutes: $0.durationMinutes,
                distanceKilometers: $0.distanceKilometers,
                averageSpeed: $0.averageSpeed,
                incline: $0.incline
            )
        } ?? []
        expandedExerciseID = validSnapshot == nil ? routine.exercises.first?.id : validSnapshot?.expandedExerciseID
        restEnd = validSnapshot?.restEnd
        restSourceSetID = validSnapshot?.restSourceSetID
        entryTexts = validSnapshot?.entryTexts ?? [:]
        isCardioExpanded = validSnapshot?.isCardioExpanded ?? (validSnapshot?.timedWalk != nil)
        selectedSetIDs = validSnapshot?.selectedSetIDs ?? [:]
        for draft in drafts {
            if !draft.sets.contains(where: { $0.id == selectedSetIDs[draft.id] }) {
                selectedSetIDs[draft.id] = draft.sets.first(where: { !$0.completed })?.id ?? draft.sets.last?.id
            }
        }
        timedWalk = validSnapshot?.timedWalk
        if let savedOrder = validSnapshot?.exercises.map(\.exerciseID) {
            drafts.sort {
                (savedOrder.firstIndex(of: $0.id) ?? savedOrder.count)
                    < (savedOrder.firstIndex(of: $1.id) ?? savedOrder.count)
            }
        }
        timedWalk?.resume(at: now)
    }

    var elapsedActiveDuration: TimeInterval {
        duration.elapsed()
    }

    var sessionTimerStartedAt: Date? {
        duration.timerStartedAt
    }

    var completedMovementCount: Int {
        drafts.filter(isExerciseComplete).count
    }

    var hasRecordedWork: Bool {
        drafts.contains { $0.sets.contains(where: \.completed) }
            || cardioDrafts.contains { $0.durationMinutes > 0 }
    }

    var currentExerciseName: String {
        if timedWalk != nil { return "Treadmill walk" }
        if let expandedExerciseID,
           let expanded = drafts.first(where: { $0.id == expandedExerciseID }) {
            return expanded.template.name
        }
        return drafts.first(where: { !isExerciseComplete($0) })?.template.name
            ?? routine.name
    }

    var snapshot: ActiveWorkoutSnapshot {
        ActiveWorkoutSnapshot(
            routineTemplate: routine,
            sessionID: sessionID,
            routineID: routine.id,
            startedAt: startedAt,
            // Running time is reconstructed from the stable timer anchor. Reading
            // the snapshot must not change it or trigger autosave on every redraw.
            activeDuration: duration.accumulated,
            exercises: drafts.map { draft in
                ActiveExerciseSnapshot(
                    exerciseID: draft.id,
                    sets: draft.sets.map {
                        ActiveSetSnapshot(
                            weight: $0.weight,
                            repetitions: $0.repetitions,
                            completed: $0.completed,
                            kind: $0.kind,
                            id: $0.id,
                            initialWeight: $0.initialWeight,
                            initialRepetitions: $0.initialRepetitions
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
            restEnd: restEnd,
            sessionTimerStartedAt: sessionTimerStartedAt,
            timedWalk: timedWalk,
            restSourceSetID: restSourceSetID,
            entryTexts: entryTexts,
            isCardioExpanded: isCardioExpanded,
            selectedSetIDs: selectedSetIDs
        )
    }

    enum FinishDisposition { case empty, partial, complete }

    func finishDisposition(at date: Date = Date()) -> FinishDisposition {
        let hasWork = hasRecordedWork || (timedWalk?.elapsed(at: date) ?? 0) > 0
        if !hasWork { return .empty }
        return completedMovementCount < drafts.count ? .partial : .complete
    }

    func pauseAndSave(at date: Date = Date(), save: (ActiveWorkoutSnapshot) throws -> Void) throws {
        pause(at: date)
        do { try save(snapshot) }
        catch {
            resume(at: date)
            throw error
        }
    }

    func finish(at date: Date = Date(), save: (WorkoutSessionState) throws -> WorkoutRecord) throws -> WorkoutRecord {
        let originalWalk = timedWalk
        let originalCardio = cardioDrafts
        pause(at: date)
        cardioDrafts.removeAll { $0.durationMinutes <= 0 }
        finishTimedWalk(now: date)
        do { return try save(self) }
        catch {
            timedWalk = originalWalk
            cardioDrafts = originalCardio
            resume(at: date)
            throw error
        }
    }

    func pause(at date: Date = Date()) {
        duration.pause(at: date)
        timedWalk?.pause(at: date)
    }

    func resume(at date: Date = Date()) {
        duration.resume(at: date)
        timedWalk?.resume(at: date)
    }

    func adjustRest(by seconds: Int, now: Date = Date()) {
        guard let restEnd else { return }
        let adjusted = restEnd.addingTimeInterval(TimeInterval(seconds))
        self.restEnd = max(adjusted, now)
    }

    func startTimedWalk(now: Date = Date()) {
        guard timedWalk == nil else { return }
        isCardioExpanded = true
        timedWalk = TimedWalk(now: now)
    }

    func finishTimedWalk(now: Date = Date()) {
        guard let walk = timedWalk else { return }
        let minutes = walk.elapsed(at: now) / 60
        if minutes > 0, !cardioDrafts.contains(where: { $0.id == walk.id }) {
            cardioDrafts.append(CardioDraft(id: walk.id, kind: .treadmillWalk, durationMinutes: minutes, averageSpeed: 0, incline: 0))
        }
        timedWalk = nil
    }

    func clearRest() {
        restEnd = nil
        restSourceSetID = nil
    }

    func undoSet(_ id: UUID) {
        if restSourceSetID == id { clearRest() }
    }

    func startManualRest(seconds: Int = 60, now: Date = Date()) {
        restSourceSetID = nil
        restEnd = now.addingTimeInterval(TimeInterval(max(1, seconds)))
    }

    func selectedSetID(for exerciseID: String) -> UUID? {
        guard let draft = drafts.first(where: { $0.id == exerciseID }) else { return nil }
        if let id = selectedSetIDs[exerciseID], draft.sets.contains(where: { $0.id == id }) { return id }
        return draft.sets.first(where: { !$0.completed })?.id ?? draft.sets.last?.id
    }

    func selectSet(_ id: UUID, for exerciseID: String) {
        guard drafts.contains(where: { $0.id == exerciseID && $0.sets.contains(where: { $0.id == id }) }) else { return }
        selectedSetIDs[exerciseID] = id
    }

    var hasRemainingWorkingSets: Bool {
        drafts.contains { $0.sets.contains { $0.kind == .working && !$0.completed } }
    }

    var recordedSetCount: Int { drafts.reduce(0) { $0 + $1.sets.filter(\.completed).count } }

    var restExerciseName: String {
        drafts.first { $0.sets.contains { $0.id == restSourceSetID } }?.template.name ?? "Rest"
    }

    func isExerciseComplete(_ draft: ExerciseDraft) -> Bool {
        let workingSets = draft.sets.filter { $0.kind == .working }
        return !workingSets.isEmpty && workingSets.allSatisfy(\.completed)
    }

    func didCompleteSet(
        for exerciseID: String,
        kind: SetKind,
        setID: UUID? = nil,
        restSeconds: Int? = nil,
        now: Date = Date()
    ) {
        guard let index = drafts.firstIndex(where: { $0.id == exerciseID }) else {
            return
        }
        let prescribedRest = max(0, restSeconds ?? drafts[index].template.restSeconds)
        let seconds = kind == .warmup ? min(90, prescribedRest) : prescribedRest
        restEnd = seconds > 0 && hasRemainingWorkingSets ? now.addingTimeInterval(TimeInterval(seconds)) : nil
        restSourceSetID = restEnd == nil ? nil : setID
        // Logging updates the activity context without navigating away from the set.
        expandedExerciseID = exerciseID
    }

    func prefillFromHistory(_ history: [WorkoutRecord]) {
        guard !resumedFromSnapshot else { return }

        for draftIndex in drafts.indices {
            let template = drafts[draftIndex].template
            guard let previousExercise = history.lazy.compactMap({ workout in
                workout.exercises.first(where: {
                    WorkoutCatalog.stableExerciseID(for: $0) == template.id
                })
            }).first else { continue }

            let previousSets = previousExercise.sets
                .filter { $0.kind == .working }
                .sorted { $0.order < $1.order }
            let workingIndices = drafts[draftIndex].sets.indices.filter {
                drafts[draftIndex].sets[$0].kind == .working
            }
            for (setIndex, previousSet) in zip(workingIndices, previousSets) {
                drafts[draftIndex].sets[setIndex].weight = previousSet.weight
                drafts[draftIndex].sets[setIndex].repetitions = previousSet.repetitions
                drafts[draftIndex].sets[setIndex].initialWeight = previousSet.weight
                drafts[draftIndex].sets[setIndex].initialRepetitions = previousSet.repetitions
            }
        }
    }
}

/// Local exercise preferences apply to future sessions without altering the routine.
enum ExerciseRestPreference {
    static func key(for exerciseID: String) -> String { "exercise-rest-seconds-" + exerciseID }

    static func seconds(for exercise: ExerciseTemplate, defaults: UserDefaults = .standard) -> Int {
        guard defaults.object(forKey: key(for: exercise.id)) != nil else { return exercise.restSeconds }
        return max(0, defaults.integer(forKey: key(for: exercise.id)))
    }
}
