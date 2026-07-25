import Foundation
import SwiftData

@Model
final class WorkoutRecord {
    var healthSyncIdentifier: UUID = UUID()
    var healthKitWorkoutUUID: UUID?
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
        healthSyncIdentifier = UUID()
        healthKitWorkoutUUID = nil
        self.date = date
        self.routineName = routineName
        self.duration = duration
        self.exercises = exercises
        self.cardioEntries = cardioEntries
    }
}

@Model
final class ExerciseRecord {
    var exerciseID: String = ""
    var name: String
    var assetName: String
    var order: Int
    var workout: WorkoutRecord?

    @Relationship(deleteRule: .cascade, inverse: \SetRecord.exercise)
    var sets: [SetRecord]

    init(
        exerciseID: String,
        name: String,
        assetName: String,
        order: Int,
        sets: [SetRecord] = []
    ) {
        self.exerciseID = exerciseID
        self.name = name
        self.assetName = assetName
        self.order = order
        self.sets = sets
    }
}

enum ExerciseIdentityMigration {
    static func backfillLegacyRecords(in modelContext: ModelContext) throws {
        let records = try modelContext.fetch(FetchDescriptor<ExerciseRecord>())
        var changed = false

        for record in records where record.exerciseID.isEmpty {
            record.exerciseID = WorkoutCatalog.stableExerciseID(for: record)
            changed = true
        }

        if changed {
            try modelContext.save()
        }
    }
}

@Model
final class SetRecord {
    var order: Int
    var weight: Double
    var repetitions: Int
    var kindRawValue: String = SetKind.working.rawValue
    var exercise: ExerciseRecord?

    var kind: SetKind {
        get { SetKind(rawValue: kindRawValue) ?? .working }
        set { kindRawValue = newValue.rawValue }
    }

    init(order: Int, weight: Double, repetitions: Int, kind: SetKind = .working) {
        self.order = order
        self.weight = weight
        self.repetitions = repetitions
        kindRawValue = kind.rawValue
    }
}

enum SetKind: String, CaseIterable, Identifiable, Codable {
    case warmup
    case working

    var id: String { rawValue }

    var title: String {
        switch self {
        case .warmup: "Warm-up"
        case .working: "Working"
        }
    }

    var shortTitle: String {
        switch self {
        case .warmup: "W"
        case .working: "WORK"
        }
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
    var kind: SetKind?
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
    var restEnd: Date?
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
