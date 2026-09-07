import Foundation
import SwiftData
import SwiftUI

struct RoutineDetailView: View {
    private let originalRoutine: RoutineTemplate
    @EnvironmentObject private var planner: PlannerStore
    init(routine: RoutineTemplate) { originalRoutine = routine }
    private var planned: PlannedSession? { planner.sessions.first { $0.id == originalRoutine.id } }
    private var routine: RoutineTemplate { planned?.routine ?? originalRoutine }
    @Environment(\.dismiss) private var dismiss
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

                    VStack(alignment: .leading, spacing: 12) {
                        Text(routine.name).font(.system(size: 38, weight: .medium)).tracking(-1.2)
                        Text(routine.focus).font(.title3).foregroundStyle(InkPalette.softInk)
                        if let planned {
                            Text("\(routine.exercises.count) movements · ~\(planned.estimatedMinutes) min")
                                .font(.subheadline).foregroundStyle(InkPalette.softInk)
                            if !planned.missing.isEmpty {
                                Label("Not included: \(planned.missing.map(\.title).joined(separator: ", ")). No matching equipment in your gym.", systemImage: "info.circle")
                                    .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 28)

                    ForEach(routine.exercises) { exercise in
                        VStack(spacing: 0) {
                            NavigationLink(value: exercise) { ExercisePatternRow(exercise: exercise) }
                                .buttonStyle(PressableButtonStyle())
                            if let planned, let movement = planned.movements.first(where: { $0.id == exercise.id }) {
                                let options = WorkoutPlanner.available(in: planner.profile, pattern: movement.exercise.pattern)
                                HStack {
                                    Text(movement.exercise.pattern.title).font(.caption).foregroundStyle(InkPalette.softInk)
                                    Spacer()
                                    if options.count > 1 {
                                        Menu("Swap movement") {
                                            ForEach(options.filter { $0.id != exercise.id }) { option in
                                                Button(option.name) { planner.swap(movement, in: planned, to: option) }
                                            }
                                        }.font(.subheadline).frame(minHeight: 44)
                                    } else {
                                        Text("Only match in your gym").font(.caption).foregroundStyle(InkPalette.softInk)
                                    }
                                }
                            }
                            InkDivider()
                        }.padding(.bottom, 10)
                    }
                    if planned != nil {
                        let cardio = GymEquipment.allCases.filter { $0.isCardio && planner.profile.equipment.contains($0) }
                        if !cardio.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Room for a little cardio").font(.headline)
                                Text(cardio.map(\.title).joined(separator: " · ")).font(.subheadline)
                                Text("Optional. Log it during your session; it is not included in the time estimate.")
                                    .font(.caption).foregroundStyle(InkPalette.softInk)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 20)
                        }
                    }
                    Text("Start with a comfortable load. Review the movements and adjust the sets as you train.")
                        .font(.subheadline).foregroundStyle(InkPalette.softInk).padding(.top, 20)

                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 104)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background { InteractivePopGestureBridge(isEnabled: true) }
        .safeAreaInset(edge: .bottom) {
            InkPrimaryButton(title: "Start \(routine.name)") { requestWorkoutStart() }
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
               let activeRoutine = startConflict.resolvedRoutine {
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
              let activeRoutine = startConflict.resolvedRoutine else {
            return "Session already in progress"
        }
        return "\(activeRoutine.name) is already in progress"
    }

    private func requestWorkoutStart() {
        guard let snapshot = ActiveWorkoutStore.load() else {
            workoutLaunch = WorkoutLaunch(routine: routine, snapshot: nil)
            return
        }
        guard snapshot.resolvedRoutine != nil else {
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
    let exercise: ExerciseTemplate

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.name)
                    .font(.system(.body, design: .default))
                    .foregroundStyle(InkPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(exercise.targetText) · rest \(exercise.restSeconds) sec")
                    .font(.system(.subheadline))
                    .foregroundStyle(InkPalette.softInk.opacity(0.82))
            }

            Spacer(minLength: 0)

            DemonstrationImage(assetName: exercise.assetName, outlined: false)
                .frame(width: 58, height: 54)
        }
        .padding(.vertical, 7)
        .frame(minHeight: 76)
        .contentShape(Rectangle())
    }
}

private struct RoutineStartButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.body, design: .default))
                .foregroundStyle(InkPalette.ink)
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity, minHeight: 58)
        }
        .buttonStyle(PressableButtonStyle())
    }
}
