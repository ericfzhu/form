import CoreTransferable
import Foundation
import SwiftData
import UniformTypeIdentifiers

struct WorkoutBackup: Transferable {
    let payload: WorkoutBackupPayload

    init(workouts: [WorkoutRecord], exportedAt: Date = Date()) {
        payload = WorkoutBackupPayload(
            version: 1,
            exportedAt: exportedAt,
            workouts: workouts
                .sorted { $0.date < $1.date }
                .map(BackupWorkout.init)
        )
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { backup in
            let date = backup.payload.exportedAt.formatted(
                .iso8601.year().month().day()
            )
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Form Backup \(date)")
                .appendingPathExtension("json")
            let data = try encoder.encode(backup.payload)
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }

    @MainActor
    static func restore(
        data: Data,
        into modelContext: ModelContext
    ) throws -> Int {
        let payload = try decoder.decode(WorkoutBackupPayload.self, from: data)
        guard payload.version == 1 else {
            throw WorkoutBackupError.unsupportedVersion(payload.version)
        }

        let existing = try modelContext.fetch(FetchDescriptor<WorkoutRecord>())
        var identifiers = Set(existing.map(\.healthSyncIdentifier))
        var importedCount = 0

        for backup in payload.workouts where !identifiers.contains(backup.id) {
            let record = backup.makeRecord()
            modelContext.insert(record)
            identifiers.insert(backup.id)
            importedCount += 1
        }

        if importedCount > 0 {
            try modelContext.save()
        }
        return importedCount
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

struct WorkoutBackupPayload: Codable {
    let version: Int
    let exportedAt: Date
    let workouts: [BackupWorkout]
}

struct BackupWorkout: Codable {
    let id: UUID
    let date: Date
    let routineID: String
    let routineName: String
    let sessionTitle: String?
    let duration: TimeInterval
    let exercises: [BackupExercise]
    let cardio: [BackupCardio]

    init(_ record: WorkoutRecord) {
        id = record.healthSyncIdentifier
        date = record.date
        routineID = record.routineID
        routineName = record.routineName
        sessionTitle = record.sessionTitle
        duration = record.duration
        exercises = record.exercises
            .sorted { $0.order < $1.order }
            .map(BackupExercise.init)
        cardio = record.cardioEntries
            .sorted { $0.order < $1.order }
            .map(BackupCardio.init)
    }

    func makeRecord() -> WorkoutRecord {
        let record = WorkoutRecord(
            date: date,
            routineID: routineID,
            routineName: routineName,
            sessionTitle: sessionTitle,
            duration: duration
        )
        record.healthSyncIdentifier = id
        record.healthSyncStatus = .notRequested
        record.exercises = exercises.map { $0.makeRecord() }
        record.cardioEntries = cardio.map { $0.makeRecord() }
        return record
    }
}

struct BackupExercise: Codable {
    let exerciseID: String
    let name: String
    let assetName: String
    let order: Int
    let sets: [BackupSet]

    init(_ record: ExerciseRecord) {
        exerciseID = record.exerciseID
        name = record.name
        assetName = record.assetName
        order = record.order
        sets = record.sets.sorted { $0.order < $1.order }.map(BackupSet.init)
    }

    func makeRecord() -> ExerciseRecord {
        ExerciseRecord(
            exerciseID: exerciseID,
            name: name,
            assetName: assetName,
            order: order,
            sets: sets.map { $0.makeRecord() }
        )
    }
}

struct BackupSet: Codable {
    let order: Int
    let weight: Double
    let repetitions: Int
    let kind: SetKind

    init(_ record: SetRecord) {
        order = record.order
        weight = record.weight
        repetitions = record.repetitions
        kind = record.kind
    }

    func makeRecord() -> SetRecord {
        SetRecord(
            order: order,
            weight: weight,
            repetitions: repetitions,
            kind: kind
        )
    }
}

struct BackupCardio: Codable {
    let kind: CardioKind
    let order: Int
    let durationMinutes: Double
    let distanceKilometers: Double
    let averageSpeed: Double
    let incline: Double

    init(_ record: CardioRecord) {
        kind = record.kind
        order = record.order
        durationMinutes = record.durationMinutes
        distanceKilometers = record.distanceKilometers
        averageSpeed = record.averageSpeed
        incline = record.incline
    }

    func makeRecord() -> CardioRecord {
        CardioRecord(
            kind: kind,
            order: order,
            durationMinutes: durationMinutes,
            distanceKilometers: distanceKilometers,
            averageSpeed: averageSpeed,
            incline: incline
        )
    }
}

enum WorkoutBackupError: LocalizedError {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            "This Form backup uses unsupported version \(version)."
        }
    }
}
