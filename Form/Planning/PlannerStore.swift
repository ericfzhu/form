import Foundation
import SwiftUI

@MainActor
final class PlannerStore: ObservableObject {
    @Published var profile: GymProfile {
        didSet {
            do { defaults.set(try JSONEncoder().encode(profile), forKey: Self.key); storageMessage = nil }
            catch { storageMessage = "Your gym changes could not be saved. Please try again." }
        }
    }
    @Published var storageMessage: String?
    private let defaults: UserDefaults
    private static let key = "form-gym-profile-v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key), let saved = try? JSONDecoder().decode(GymProfile.self, from: data) {
            profile = saved
        } else { profile = GymProfile() }
    }

    var sessions: [PlannedSession] { WorkoutPlanner.sessions(for: profile) }
    func swap(_ movement: PlannedMovement, in session: PlannedSession, to exercise: PlanningExercise) {
        guard exercise.pattern == movement.exercise.pattern, exercise.isAvailable(in: profile) else { return }
        profile.overrides["\(session.id)-\(exercise.pattern.rawValue)"] = exercise.id
    }
}

extension PlannedSession {
    var routine: RoutineTemplate {
        RoutineTemplate(id: id, name: name, focus: subtitle, exercises: movements.map { movement in
            let measurement: ExerciseTemplate.Measurement
            switch movement.exercise.measurement {
            case "bodyweight": measurement = .bodyweight
            case "timed": measurement = .timed
            case "weightedTimed": measurement = .weightedTimed
            default: measurement = .weighted
            }
            return ExerciseTemplate(id: movement.id, name: movement.exercise.name, assetName: movement.id,
                sets: movement.sets, minimumRepetitions: movement.minimum, maximumRepetitions: movement.maximum,
                measurement: measurement, restSeconds: movement.restSeconds)
        })
    }
}

extension ActiveWorkoutSnapshot {
    var resolvedRoutine: RoutineTemplate? {
        routineTemplate ?? WorkoutCatalog.routine(id: routineID)
    }
}
