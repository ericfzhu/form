import Foundation

struct ExerciseTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let assetName: String
    let sets: Int
    let minimumRepetitions: Int
    let maximumRepetitions: Int
    let measurement: Measurement

    enum Measurement: Hashable {
        case weighted
        case bodyweight
        case timed
    }

    var targetText: String {
        switch measurement {
        case .timed:
            return "\(sets) × 30–45 sec"
        default:
            return "\(sets) × \(minimumRepetitions)–\(maximumRepetitions)"
        }
    }
}

struct RoutineTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let focus: String
    let exercises: [ExerciseTemplate]
}

enum WorkoutCatalog {
    static let routines: [RoutineTemplate] = [
        RoutineTemplate(
            id: "A",
            name: "Workout A",
            focus: "Squat · press · pull",
            exercises: [
                exercise("barbell-back-squat", "Barbell Back Squat", 3, 6, 10),
                exercise("chest-press", "Dumbbell Chest Press", 3, 6, 10),
                exercise("seated-row", "Seated Cable Row", 3, 8, 12),
                exercise("romanian-deadlift", "Romanian Deadlift", 2, 8, 10),
                exercise("lat-pulldown", "Lat Pulldown", 2, 8, 12),
                timed("plank", "Plank", 2)
            ]
        ),
        RoutineTemplate(
            id: "B",
            name: "Workout B",
            focus: "Hinge · incline · unilateral",
            exercises: [
                exercise("conventional-deadlift", "Conventional Barbell Deadlift", 3, 5, 6),
                exercise("incline-press", "Incline Dumbbell Press", 3, 8, 12),
                exercise("underhand-lat-pulldown", "Underhand Lat Pulldown", 3, 8, 12),
                exercise("split-squat", "Split Squat", 2, 8, 12),
                exercise("chest-supported-row", "Chest-Supported Row", 2, 8, 12),
                timed("side-plank", "Side Plank", 2)
            ]
        ),
        RoutineTemplate(
            id: "C",
            name: "Workout C",
            focus: "Squat · shoulders · carry",
            exercises: [
                exercise("goblet-squat", "Goblet Squat", 3, 8, 12),
                exercise("shoulder-press", "Dumbbell Shoulder Press", 3, 8, 12),
                exercise("cable-row", "Cable Row", 3, 8, 12),
                exercise("leg-curl", "Leg Curl", 2, 10, 15),
                bodyweight("pushup", "Push-Up", 2, 8, 15),
                timed("farmer-carry", "Farmer Carry", 3)
            ]
        )
    ]

    static func exercise(named name: String) -> ExerciseTemplate? {
        routines
            .flatMap(\.exercises)
            .first { $0.name == name }
    }

    private static func exercise(_ asset: String, _ name: String, _ sets: Int, _ minimum: Int, _ maximum: Int) -> ExerciseTemplate {
        ExerciseTemplate(id: asset, name: name, assetName: asset, sets: sets, minimumRepetitions: minimum, maximumRepetitions: maximum, measurement: .weighted)
    }

    private static func bodyweight(_ asset: String, _ name: String, _ sets: Int, _ minimum: Int, _ maximum: Int) -> ExerciseTemplate {
        ExerciseTemplate(id: asset, name: name, assetName: asset, sets: sets, minimumRepetitions: minimum, maximumRepetitions: maximum, measurement: .bodyweight)
    }

    private static func timed(_ asset: String, _ name: String, _ sets: Int) -> ExerciseTemplate {
        ExerciseTemplate(id: asset, name: name, assetName: asset, sets: sets, minimumRepetitions: 30, maximumRepetitions: 45, measurement: .timed)
    }
}
