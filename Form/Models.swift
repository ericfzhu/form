import Foundation
import SwiftData

@Model
final class WorkoutRecord {
    var healthSyncIdentifier: UUID = UUID()
    var healthKitWorkoutUUID: UUID?
    var healthSyncStatusRawValue: String = HealthSyncStatus.notRequested.rawValue
    var healthSyncLastAttemptAt: Date?
    var healthSyncLastError: String?
    var date: Date = Date()
    var routineID: String = ""
    var routineName: String = ""
    var sessionTitle: String?
    var duration: TimeInterval = 0

    @Relationship(
        deleteRule: .cascade,
        originalName: "exercises",
        inverse: \ExerciseRecord.workout
    )
    var storedExercises: [ExerciseRecord]? = []

    @Relationship(
        deleteRule: .cascade,
        originalName: "cardioEntries",
        inverse: \CardioRecord.workout
    )
    var storedCardioEntries: [CardioRecord]? = []

    var exercises: [ExerciseRecord] {
        get { storedExercises ?? [] }
        set { storedExercises = newValue }
    }

    var cardioEntries: [CardioRecord] {
        get { storedCardioEntries ?? [] }
        set { storedCardioEntries = newValue }
    }

    var healthSyncStatus: HealthSyncStatus {
        get { HealthSyncStatus(rawValue: healthSyncStatusRawValue) ?? .notRequested }
        set { healthSyncStatusRawValue = newValue.rawValue }
    }

    var displayName: String {
        let trimmed = sessionTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? routineName : trimmed
    }

    init(
        date: Date,
        routineID: String = "",
        routineName: String,
        sessionTitle: String? = nil,
        duration: TimeInterval,
        exercises: [ExerciseRecord] = [],
        cardioEntries: [CardioRecord] = []
    ) {
        healthSyncIdentifier = UUID()
        healthKitWorkoutUUID = nil
        healthSyncStatusRawValue = HealthSyncStatus.notRequested.rawValue
        self.date = date
        self.routineID = routineID
        self.routineName = routineName
        self.sessionTitle = sessionTitle
        self.duration = duration
        storedExercises = exercises
        storedCardioEntries = cardioEntries
    }
}

enum HealthSyncStatus: String, Codable, CaseIterable {
    case notRequested
    case pending
    case syncing
    case synced
    case failed

    var title: String {
        switch self {
        case .notRequested: "Local only"
        case .pending: "Apple Health pending"
        case .syncing: "Saving to Apple Health"
        case .synced: "Saved to Apple Health"
        case .failed: "Apple Health needs retry"
        }
    }
}

@Model
final class ExerciseRecord {
    var exerciseID: String = ""
    var name: String = ""
    var assetName: String = ""
    var order: Int = 0
    var workout: WorkoutRecord?

    @Relationship(
        deleteRule: .cascade,
        originalName: "sets",
        inverse: \SetRecord.exercise
    )
    var storedSets: [SetRecord]? = []

    var sets: [SetRecord] {
        get { storedSets ?? [] }
        set { storedSets = newValue }
    }

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
        storedSets = sets
    }
}

enum WorkoutDataMigration {
    static func backfillLegacyRecords(in modelContext: ModelContext) throws {
        var changed = false
        let workouts = try modelContext.fetch(FetchDescriptor<WorkoutRecord>())

        for workout in workouts {
            if workout.routineID.isEmpty {
                workout.routineID = WorkoutCatalog.routineID(
                    forLegacyName: workout.routineName,
                    exerciseIDs: workout.exercises.map {
                        WorkoutCatalog.stableExerciseID(for: $0)
                    }
                ) ?? "custom"
                changed = true
            }

            if let routine = WorkoutCatalog.routine(id: workout.routineID),
               workout.routineName != routine.name {
                if workout.sessionTitle?.isEmpty ?? true,
                   !workout.routineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    workout.sessionTitle = workout.routineName
                }
                workout.routineName = routine.name
                changed = true
            }

            if workout.healthKitWorkoutUUID != nil,
               workout.healthSyncStatus != .synced {
                workout.healthSyncStatus = .synced
                changed = true
            }
        }

        let exercises = try modelContext.fetch(FetchDescriptor<ExerciseRecord>())
        for exercise in exercises where exercise.exerciseID.isEmpty {
            exercise.exerciseID = WorkoutCatalog.stableExerciseID(for: exercise)
            changed = true
        }

        if changed {
            try modelContext.save()
        }
    }
}

/// Keeps the existing RootView migration call source-compatible.
enum ExerciseIdentityMigration {
    static func backfillLegacyRecords(in modelContext: ModelContext) throws {
        try WorkoutDataMigration.backfillLegacyRecords(in: modelContext)
    }
}

@Model
final class SetRecord {
    var order: Int = 0
    var weight: Double = 0
    var repetitions: Int = 0
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
    var sessionID: UUID? = nil
    var routineID: String
    var startedAt: Date
    var activeDuration: TimeInterval?
    var exercises: [ActiveExerciseSnapshot]
    var cardio: [ActiveCardioSnapshot]
    var expandedExerciseID: String?
    var restEnd: Date?
}

struct CardioDraft: Identifiable, Equatable, Codable {
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
    var kindRawValue: String = CardioKind.other.rawValue
    var order: Int = 0
    var durationMinutes: Double = 0
    var distanceKilometers: Double = 0
    var averageSpeed: Double = 0
    var incline: Double = 0
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

extension WorkoutRecord {
    var hasTrainingData: Bool {
        exercises.contains { exercise in
            exercise.sets.contains { $0.kind == .working }
        } || cardioEntries.contains { $0.durationMinutes > 0 }
    }
}
