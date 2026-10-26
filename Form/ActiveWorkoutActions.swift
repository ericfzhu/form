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

    var numberFields: [NumberFieldSpec] {
        session.drafts.flatMap { draft in
            draft.sets.flatMap { set -> [NumberFieldSpec] in
                var fields: [NumberFieldSpec] = []
                if draft.template.recordsLoad {
                    fields.append(NumberFieldSpec(id: EntryID.load(set.id), label: "\(draft.template.name), weight", value: set.weight, rule: .load))
                }
                fields.append(NumberFieldSpec(id: EntryID.count(set.id), label: "\(draft.template.name), \(draft.template.recordsTime ? "seconds" : "repetitions")", value: Double(set.repetitions), rule: .count))
                return fields
            }
        } + session.cardioDrafts.flatMap(\.numberFields)
    }

    func adjustFocusedInput(by direction: Double) {
        guard let focusedInput, entryForm.validate(ids: [focusedInput.id]),
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
        // Preserve the deadline so the Live Activity can display Ready.
        RestFeedbackService.shared.finishInForeground()
        Task { await WorkoutLiveActivityController.update(session: session) }
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
        guard !didEndSession, entryForm.validate() else { return }
        entryForm.done()
        dismissKeyboard()
        switch session.finishDisposition() {
        case .empty: showingEmptyFinishConfirmation = true
        case .partial: showingIncompleteFinishConfirmation = true
        case .complete: finishWorkout()
        }
    }

    func scheduleSnapshotSave(_ snapshot: ActiveWorkoutSnapshot) {
        snapshotSaveTask?.cancel()
        snapshotSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, !didEndSession, completedRecord == nil else { return }
            do {
                try ActiveWorkoutStore.save(snapshot)
            } catch {
                saveErrorMessage = "Your active workout could not be preserved. \(error.localizedDescription)"
            }
        }
    }

    func persistImmediately() {
        guard !didEndSession, completedRecord == nil else { return }
        do {
            try ActiveWorkoutStore.save(session.snapshot)
        } catch {
            saveErrorMessage = "Your active workout could not be preserved. \(error.localizedDescription)"
        }
    }

    func discardWorkout() {
        do { try ActiveWorkoutStore.clearChecked() }
        catch {
            saveErrorMessage = "Couldn’t discard the session. Try again."
            return
        }
        didEndSession = true
        snapshotSaveTask?.cancel()
        RestFeedbackService.shared.cancel()
        UIApplication.shared.isIdleTimerDisabled = false
        Task { await WorkoutLiveActivityController.forceEnd() }
        dismiss()
    }

    func saveAndClose() {
        guard !didEndSession, entryForm.validate() else { return }
        entryForm.done()
        dismissKeyboard()
        snapshotSaveTask?.cancel()
        do { try session.pauseAndSave { try ActiveWorkoutStore.save($0) } }
        catch {
            saveErrorMessage = "Your session is still open. Couldn’t save it for later; try Pause and close again."
            return
        }
        RestFeedbackService.shared.cancel()
        UIApplication.shared.isIdleTimerDisabled = false
        Task { await WorkoutLiveActivityController.pause(snapshot: session.snapshot) }
        dismiss()
    }

    func finishWorkout() {
        guard !didEndSession, entryForm.validate() else { return }
        do {
            let record = try session.finish {
                try WorkoutRepository.saveCompletedSession($0, in: modelContext)
            }
            didEndSession = true
            snapshotSaveTask?.cancel()
            ActiveWorkoutStore.clear()
            session.clearRest()
            RestFeedbackService.shared.cancel()
            UIApplication.shared.isIdleTimerDisabled = false
            Task { await WorkoutLiveActivityController.forceEnd() }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
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
            session.resume()
            persistImmediately()
            saveErrorMessage = "Nothing was lost from this active session. Try saving again."
        }
    }

    func updateScreenAwakeState() {
        UIApplication.shared.isIdleTimerDisabled = keepScreenAwake && completedRecord == nil
    }
}
