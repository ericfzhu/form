import Foundation
import Observation

struct SetDraft: Identifiable {
    let id: UUID
    var weight: Double
    var repetitions: Int
    var completed: Bool
    var kind: SetKind

    init(
        id: UUID = UUID(),
        weight: Double,
        repetitions: Int,
        completed: Bool = false,
        kind: SetKind = .working
    ) {
        self.id = id
        self.weight = weight
        self.repetitions = repetitions
        self.completed = completed
        self.kind = kind
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
    var restEnd: Date?
    var expandedExerciseID: String?

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
            accumulated: max(0, validSnapshot?.activeDuration ?? 0),
            segmentStartedAt: now
        )
        drafts = routine.exercises.map { exercise in
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
        expandedExerciseID = validSnapshot?.expandedExerciseID
            ?? routine.exercises.first?.id
        restEnd = validSnapshot?.restEnd.flatMap { $0 > now ? $0 : nil }
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
        if let expandedExerciseID,
           let expanded = drafts.first(where: { $0.id == expandedExerciseID }) {
            return expanded.template.name
        }
        return drafts.first(where: { !isExerciseComplete($0) })?.template.name
            ?? routine.name
    }

    var snapshot: ActiveWorkoutSnapshot {
        ActiveWorkoutSnapshot(
            sessionID: sessionID,
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

    func pause(at date: Date = Date()) {
        duration.pause(at: date)
    }

    func resume(at date: Date = Date()) {
        duration.resume(at: date)
    }

    func adjustRest(by seconds: Int, now: Date = Date()) {
        guard let restEnd else { return }
        let adjusted = restEnd.addingTimeInterval(TimeInterval(seconds))
        self.restEnd = adjusted > now ? adjusted : nil
    }

    func clearRest() {
        restEnd = nil
    }

    func isExerciseComplete(_ draft: ExerciseDraft) -> Bool {
        draft.sets.filter { $0.completed && $0.kind == .working }.count
            >= draft.template.sets
    }

    func didCompleteSet(
        for exerciseID: String,
        kind: SetKind,
        now: Date = Date()
    ) {
        guard let index = drafts.firstIndex(where: { $0.id == exerciseID }) else {
            return
        }
        let prescribedRest = drafts[index].template.restSeconds
        let seconds = kind == .warmup ? min(90, prescribedRest) : prescribedRest
        restEnd = now.addingTimeInterval(TimeInterval(seconds))

        guard isExerciseComplete(drafts[index]) else { return }
        let following = drafts.dropFirst(index + 1).first(where: {
            !isExerciseComplete($0)
        }) ?? drafts.first(where: { !isExerciseComplete($0) })
        expandedExerciseID = following?.id
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
            }
        }
    }
}
