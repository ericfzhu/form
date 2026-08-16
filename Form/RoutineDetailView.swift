import Foundation
import SwiftData
import SwiftUI

struct RoutineDetailView: View {
    let routine: RoutineTemplate
    @Environment(\.dismiss) private var dismiss
    @State private var workoutLaunch: WorkoutLaunch?
    @State private var startConflict: ActiveWorkoutSnapshot?
    @State private var shouldReturnToTrain = false

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(spacing: 14) {
                    RawScreenTitle(
                        index: routine.id,
                        title: routine.name,
                        detail: "\(routine.exercises.count) MOVEMENTS"
                    )
                    .padding(.horizontal, -20)
                    .padding(.bottom, 6)

                    ForEach(Array(routine.exercises.enumerated()), id: \.element.id) { index, exercise in
                        NavigationLink(value: exercise) {
                            ExercisePreviewRow(index: index + 1, exercise: exercise)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 104)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background { InteractivePopGestureBridge(isEnabled: true) }
        .safeAreaInset(edge: .top, spacing: 0) {
            InkTextHeader(
                title: routine.name.uppercased(),
                leadingTitle: "Back",
                leadingAction: { dismiss() }
            )
        }
        .safeAreaInset(edge: .bottom) {
            InkPrimaryButton(title: "Begin session") { requestWorkoutStart() }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(InkPalette.paper.opacity(0.94))
        }
        .confirmationDialog(
            startConflictTitle,
            isPresented: Binding(
                get: { startConflict != nil },
                set: { if !$0 { startConflict = nil } }
            )
        ) {
            if let startConflict,
               let activeRoutine = WorkoutCatalog.routine(id: startConflict.routineID) {
                Button("Resume \(activeRoutine.name)") {
                    workoutLaunch = WorkoutLaunch(routine: activeRoutine, snapshot: startConflict)
                    self.startConflict = nil
                }
                Button(
                    activeRoutine.id == routine.id
                        ? "Discard and restart"
                        : "Discard and begin \(routine.name)",
                    role: .destructive
                ) { replaceActiveWorkout() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only one session can be active at a time. Current progress remains saved unless discarded.")
        }
        .fullScreenCover(item: $workoutLaunch, onDismiss: {
            if shouldReturnToTrain { dismiss() }
        }) { launch in
            ActiveWorkoutView(routine: launch.routine, snapshot: launch.snapshot) {
                shouldReturnToTrain = true
            }
        }
    }

    private var startConflictTitle: String {
        guard let startConflict,
              let activeRoutine = WorkoutCatalog.routine(id: startConflict.routineID) else {
            return "Session already in progress"
        }
        return "\(activeRoutine.name) is already in progress"
    }

    private func requestWorkoutStart() {
        guard let snapshot = ActiveWorkoutStore.load() else {
            workoutLaunch = WorkoutLaunch(routine: routine, snapshot: nil)
            return
        }
        guard WorkoutCatalog.routine(id: snapshot.routineID) != nil else {
            ActiveWorkoutStore.clear()
            workoutLaunch = WorkoutLaunch(routine: routine, snapshot: nil)
            return
        }
        startConflict = snapshot
    }

    private func replaceActiveWorkout() {
        startConflict = nil
        ActiveWorkoutStore.clear()
        RestFeedbackService.shared.cancel()
        Task {
            await WorkoutLiveActivityController.forceEnd()
            workoutLaunch = WorkoutLaunch(routine: routine, snapshot: nil)
        }
    }
}

private struct WorkoutLaunch: Identifiable {
    let id = UUID()
    let routine: RoutineTemplate
    let snapshot: ActiveWorkoutSnapshot?
}

private struct ExercisePreviewRow: View {
    let index: Int
    let exercise: ExerciseTemplate
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]

    private var previous: ExercisePerformance? {
        ProgressionEngine.latestCompleted(for: exercise, in: workouts)
    }

    var body: some View {
        HStack(spacing: 16) {
            DemonstrationImage(assetName: exercise.assetName)
                .frame(width: 106, height: 106)
            VStack(alignment: .leading, spacing: 7) {
                Text(String(format: "%02d", index))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(InkPalette.softInk)
                Text(exercise.name)
                    .font(.system(.headline, design: .serif, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(exercise.targetText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(InkPalette.softInk)
                if let previous, let topSet = previous.topSet {
                    Text("Last · \(WorkoutValueFormatter.setText(weight: topSet.weight, repetitions: topSet.repetitions, template: exercise))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(InkPalette.cinnabar)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .inkCard()
    }
}

