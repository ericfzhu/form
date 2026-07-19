import Foundation
import SwiftData

@Model
final class WorkoutRecord {
    var date: Date
    var routineName: String
    var duration: TimeInterval

    @Relationship(deleteRule: .cascade, inverse: \ExerciseRecord.workout)
    var exercises: [ExerciseRecord]

    @Relationship(deleteRule: .cascade, inverse: \CardioRecord.workout)
    var cardioEntries: [CardioRecord]

    init(
        date: Date,
        routineName: String,
        duration: TimeInterval,
        exercises: [ExerciseRecord] = [],
        cardioEntries: [CardioRecord] = []
    ) {
        self.date = date
        self.routineName = routineName
        self.duration = duration
        self.exercises = exercises
        self.cardioEntries = cardioEntries
    }
}

@Model
final class ExerciseRecord {
    var name: String
    var assetName: String
    var order: Int
    var workout: WorkoutRecord?

    @Relationship(deleteRule: .cascade, inverse: \SetRecord.exercise)
    var sets: [SetRecord]

    init(name: String, assetName: String, order: Int, sets: [SetRecord] = []) {
        self.name = name
        self.assetName = assetName
        self.order = order
        self.sets = sets
    }
}

@Model
final class SetRecord {
    var order: Int
    var weight: Double
    var repetitions: Int
    var exercise: ExerciseRecord?

    init(order: Int, weight: Double, repetitions: Int) {
        self.order = order
        self.weight = weight
        self.repetitions = repetitions
    }
}

enum CardioKind: String, CaseIterable, Identifiable, Codable {
    case treadmillWalk
    case treadmillRun
    case cycling
    case elliptical
    case rowing
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .treadmillWalk: "Treadmill walk"
        case .treadmillRun: "Treadmill run"
        case .cycling: "Cycling"
        case .elliptical: "Elliptical"
        case .rowing: "Rowing"
        case .other: "Other cardio"
        }
    }

    var supportsIncline: Bool {
        self == .treadmillWalk || self == .treadmillRun
    }
}

struct ActiveSetSnapshot: Codable, Equatable {
    var weight: Double
    var repetitions: Int
    var completed: Bool
}

struct ActiveExerciseSnapshot: Codable, Equatable {
    var exerciseID: String
    var sets: [ActiveSetSnapshot]
}

struct ActiveCardioSnapshot: Codable, Equatable {
    var id: UUID
    var kind: CardioKind
    var durationMinutes: Double
    var distanceKilometers: Double
    var averageSpeed: Double
    var incline: Double
}

struct ActiveWorkoutSnapshot: Codable, Equatable {
    var routineID: String
    var startedAt: Date
    var exercises: [ActiveExerciseSnapshot]
    var cardio: [ActiveCardioSnapshot]
    var expandedExerciseID: String?
}

enum ActiveWorkoutStore {
    private static let key = "active-workout-snapshot-v1"

    static func load() -> ActiveWorkoutSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: data)
    }

    static func save(_ snapshot: ActiveWorkoutSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

struct CardioDraft: Identifiable {
    let id: UUID
    var kind: CardioKind
    var durationMinutes: Double
    var distanceKilometers: Double
    var averageSpeed: Double
    var incline: Double

    init(
        id: UUID = UUID(),
        kind: CardioKind = .treadmillWalk,
        durationMinutes: Double = 30,
        distanceKilometers: Double = 0,
        averageSpeed: Double = 5,
        incline: Double = 7.5
    ) {
        self.id = id
        self.kind = kind
        self.durationMinutes = durationMinutes
        self.distanceKilometers = distanceKilometers
        self.averageSpeed = averageSpeed
        self.incline = incline
    }

    init(record: CardioRecord) {
        id = UUID()
        kind = record.kind
        durationMinutes = record.durationMinutes
        distanceKilometers = record.distanceKilometers
        averageSpeed = record.averageSpeed
        incline = record.incline
    }
}

@Model
final class CardioRecord {
    var kindRawValue: String
    var order: Int
    var durationMinutes: Double
    var distanceKilometers: Double
    var averageSpeed: Double
    var incline: Double
    var workout: WorkoutRecord?

    var kind: CardioKind {
        get { CardioKind(rawValue: kindRawValue) ?? .other }
        set { kindRawValue = newValue.rawValue }
    }

    init(
        kind: CardioKind,
        order: Int,
        durationMinutes: Double,
        distanceKilometers: Double = 0,
        averageSpeed: Double = 0,
        incline: Double = 0
    ) {
        kindRawValue = kind.rawValue
        self.order = order
        self.durationMinutes = durationMinutes
        self.distanceKilometers = distanceKilometers
        self.averageSpeed = averageSpeed
        self.incline = incline
    }
}
