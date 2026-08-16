import Foundation
import SwiftData
import SwiftUI
import UIKit

extension ActiveWorkoutView {
    var inputFields: [WorkoutInputField] {
        session.drafts.flatMap { draft in
            draft.sets.flatMap { set -> [WorkoutInputField] in
                var fields: [WorkoutInputField] = []
                if draft.template.recordsLoad {
                    fields.append(WorkoutInputField(
                        exerciseID: draft.id,
                        setID: set.id,
                        value: .load
                    ))
                }
                fields.append(WorkoutInputField(
                    exerciseID: draft.id,
                    setID: set.id,
                    value: .repetitions
                ))
                return fields
            }
        }
    }

    func canMoveInputFocus(by offset: Int) -> Bool {
        guard let focusedInput,
              let index = inputFields.firstIndex(of: focusedInput) else { return false }
        return inputFields.indices.contains(index + offset)
    }

    func moveInputFocus(by offset: Int) {
        guard let focusedInput,
              let index = inputFields.firstIndex(of: focusedInput),
              inputFields.indices.contains(index + offset) else { return }
        self.focusedInput = inputFields[index + offset]
    }

    func adjustFocusedInput(by direction: Double) {
        guard let focusedInput,
              let exerciseIndex = session.drafts.firstIndex(where: {
                  $0.id == focusedInput.exerciseID
              }),
              let setIndex = session.drafts[exerciseIndex].sets.firstIndex(where: {
                  $0.id == focusedInput.setID
              }) else { return }

        switch focusedInput.value {
        case .load:
            session.drafts[exerciseIndex].sets[setIndex].weight = max(
                0,
                session.drafts[exerciseIndex].sets[setIndex].weight
                    + direction * loadIncrement
            )
        case .repetitions:
            session.drafts[exerciseIndex].sets[setIndex].repetitions = max(
                0,
                session.drafts[exerciseIndex].sets[setIndex].repetitions + Int(direction)
            )
        }
    }

    func adjustRest(by seconds: Int) {
        session.adjustRest(by: seconds)
        scheduleRestFeedback()
    }

    func clearRest() {
        session.clearRest()
        RestFeedbackService.shared.cancel()
    }

    func completeRest() {
        session.clearRest()
        RestFeedbackService.shared.finishInForeground()
    }

    func scheduleRestFeedback() {
        guard let end = session.restEnd, end > Date() else {
            RestFeedbackService.shared.cancel()
            return
        }
        RestFeedbackService.shared.schedule(
            end: end,
            exerciseName: session.currentExerciseName
        )
    }

    func requestFinish() {
        if !session.hasRecordedWork {
            showingEmptyFinishConfirmation = true
        } else if session.completedMovementCount < session.drafts.count {
            showingIncompleteFinishConfirmation = true
        } else {
            finishWorkout()
        }
    }

    func scheduleSnapshotSave(_ snapshot: ActiveWorkoutSnapshot) {
        snapshotSaveTask?.cancel()
        snapshotSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            do {
                try ActiveWorkoutStore.save(snapshot)
            } catch {
                saveErrorMessage = "Your active workout could not be preserved. \(error.localizedDescription)"
            }
        }
    }

    func persistImmediately() {
        do {
            try ActiveWorkoutStore.save(session.snapshot)
        } catch {
            saveErrorMessage = "Your active workout could not be preserved. \(error.localizedDescription)"
        }
    }

    func discardWorkout() {
        didEndSession = true
        snapshotSaveTask?.cancel()
        ActiveWorkoutStore.clear()
        RestFeedbackService.shared.cancel()
        UIApplication.shared.isIdleTimerDisabled = false
        Task { await WorkoutLiveActivityController.forceEnd() }
        dismiss()
    }

    func saveAndClose() {
        session.pause()
        snapshotSaveTask?.cancel()
        persistImmediately()
        UIApplication.shared.isIdleTimerDisabled = false
        Task { await WorkoutLiveActivityController.pause(snapshot: session.snapshot) }
        dismiss()
    }

    func finishWorkout() {
        session.pause()
        do {
            let record = try WorkoutRepository.saveCompletedSession(
                session,
                in: modelContext
            )
            didEndSession = true
            snapshotSaveTask?.cancel()
            ActiveWorkoutStore.clear()
            session.clearRest()
            RestFeedbackService.shared.cancel()
            UIApplication.shared.isIdleTimerDisabled = false
            Task { await WorkoutLiveActivityController.forceEnd() }
            withAnimation(.easeOut(duration: 0.22)) {
                completedRecord = record
            }
            Task {
                await HealthSyncCoordinator.shared.enqueueSave(
                    record,
                    in: modelContext
                )
            }
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Nothing was lost from this active session. Try saving again."
        }
    }

    func updateScreenAwakeState() {
        UIApplication.shared.isIdleTimerDisabled = keepScreenAwake && completedRecord == nil
    }
}
