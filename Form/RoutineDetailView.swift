import Foundation
import SwiftData
import SwiftUI

struct RoutineDetailView: View {
    let routine: RoutineTemplate
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]
    @State private var workoutLaunch: WorkoutLaunch?
    @State private var startConflict: ActiveWorkoutSnapshot?
    @State private var shouldReturnToTrain = false

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(spacing: 0) {
                    HStack {
                        Button("Back") { dismiss() }
                            .font(AtelierType.script(16))
                            .foregroundStyle(InkPalette.softInk)
                            .frame(minWidth: 50, minHeight: 44, alignment: .leading)
                            .buttonStyle(PressableButtonStyle())

                        Spacer()

                        if let firstExercise = routine.exercises.first {
                            NavigationLink(value: firstExercise) {
                                Text("Exercise progress")
                                    .font(AtelierType.script(16))
                                    .foregroundStyle(InkPalette.mineral)
                                    .frame(minWidth: 116, minHeight: 44, alignment: .trailing)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }

                    ZStack(alignment: .topTrailing) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(routine.name)
                                .font(AtelierType.script(33))
                                .foregroundStyle(InkPalette.ink)
                            Text(isNextRoutine ? "next in the rotation" : "in the training rotation")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(InkPalette.mineral)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)

                        if let firstExercise = routine.exercises.first {
                            DemonstrationImage(assetName: firstExercise.assetName, outlined: false)
                                .frame(width: 220, height: 172)
                                .rotationEffect(.degrees(0.5))
                                .offset(x: 12, y: 12)
                        }
                    }
                    .frame(minHeight: 194)

                    if let firstExercise = routine.exercises.first,
                       let topSet = latestTopSet(for: firstExercise) {
                        Text("previous · \(WorkoutValueFormatter.setText(weight: topSet.weight, repetitions: topSet.repetitions, template: firstExercise))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(InkPalette.washedInk)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.bottom, 8)
                    }

                    ForEach(Array(routine.exercises.enumerated()), id: \.element.id) { index, exercise in
                        NavigationLink(value: exercise) {
                            ExercisePatternRow(index: index + 1, exercise: exercise)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 104)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background { InteractivePopGestureBridge(isEnabled: true) }
        .safeAreaInset(edge: .bottom) {
            RoutineStartButton(title: "Begin \(routine.name)") { requestWorkoutStart() }
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

    private var isNextRoutine: Bool {
        WorkoutCatalog.nextRoutine(after: workouts.first).id == routine.id
    }

    private func latestTopSet(for exercise: ExerciseTemplate) -> PerformanceSetValue? {
        ProgressionEngine.latestCompleted(for: exercise, in: workouts)?.topSet
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

private struct ExercisePatternRow: View {
    let index: Int
    let exercise: ExerciseTemplate
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]

    private var previous: ExercisePerformance? {
        ProgressionEngine.latestCompleted(for: exercise, in: workouts)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(InkPalette.softInk)
            .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.name)
                    .font(AtelierType.script(18))
                    .foregroundStyle(InkPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(exercise.targetText) · rest \(exercise.restSeconds) sec")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(InkPalette.softInk.opacity(0.82))
            }

            Spacer(minLength: 0)

            if let previous, let topSet = previous.topSet {
                Text(WorkoutValueFormatter.setText(
                    weight: topSet.weight,
                    repetitions: topSet.repetitions,
                    template: exercise
                ))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(InkPalette.washedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            }

            DemonstrationImage(assetName: exercise.assetName, outlined: false)
                .frame(width: 68, height: 62)
        }
        .padding(.vertical, 7)
        .frame(minHeight: 76)
        .overlay(alignment: .bottom) { InkDivider().opacity(0.38) }
        .contentShape(Rectangle())
    }
}

private struct RoutineStartButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(AtelierType.script(21))
                    .foregroundStyle(InkPalette.ink)
                Spacer()
            }
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity, minHeight: 58)
            .overlay(alignment: .top) { InkDivider() }
            .overlay(alignment: .bottom) { InkDivider() }
        }
        .buttonStyle(PressableButtonStyle())
    }
}
