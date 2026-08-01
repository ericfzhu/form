import Foundation
import HealthKit

enum HealthAccessState: Equatable {
    case unavailable
    case notConnected
    case connected
    case denied
}

enum HealthWorkoutSyncState: Equatable {
    case notConnected
    case syncing
    case saved
    case failed
}

@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    @Published private(set) var accessState: HealthAccessState = .notConnected
    @Published private(set) var latestBodyMassKilograms: Double?
    @Published private(set) var errorMessage: String?

    private let healthStore = HKHealthStore()

    private var workoutType: HKWorkoutType {
        HKObjectType.workoutType()
    }

    private var bodyMassType: HKQuantityType {
        HKObjectType.quantityType(forIdentifier: .bodyMass)!
    }

    private var workoutShareTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = [
            workoutType,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!
        ]
        if #available(iOS 18.0, *),
           let rowingDistance = HKObjectType.quantityType(forIdentifier: .distanceRowing) {
            types.insert(rowingDistance)
        }
        return types
    }

    var canWriteWorkouts: Bool {
        accessState == .connected
    }

    private init() {
        refreshAccessState()
    }

    func refresh() async {
        refreshAccessState()
        guard accessState == .connected else {
            latestBodyMassKilograms = nil
            return
        }

        do {
            latestBodyMassKilograms = try await fetchLatestBodyMass()
            errorMessage = nil
        } catch {
            latestBodyMassKilograms = nil
            errorMessage = "Form couldn’t read your latest body weight."
        }
    }

    func requestAccess() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            accessState = .unavailable
            return
        }

        do {
            try await healthStore.requestAuthorization(
                toShare: workoutShareTypes,
                read: [bodyMassType]
            )
            refreshAccessState()
            if accessState == .connected {
                latestBodyMassKilograms = try await fetchLatestBodyMass()
            }
            errorMessage = nil
        } catch {
            refreshAccessState()
            errorMessage = "Apple Health access couldn’t be completed."
        }
    }

    func saveWorkout(
        from record: WorkoutRecord,
        replacing previousWorkoutUUID: UUID? = nil
    ) async throws -> UUID? {
        guard canWriteWorkouts, record.hasTrainingData else { return nil }

        let endDate = record.date.addingTimeInterval(max(1, record.duration))
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = record.healthActivityType
        configuration.locationType = .indoor

        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: .local()
        )

        do {
            try await builder.beginCollection(at: record.date)
            try await builder.addMetadata([
                HKMetadataKeyIndoorWorkout: true,
                HKMetadataKeyExternalUUID: record.healthSyncIdentifier.uuidString
            ])

            if let distance = record.healthDistance,
               let distanceType = record.healthDistanceType,
               healthStore.authorizationStatus(for: distanceType) == .sharingAuthorized {
                let sampleStart = min(
                    endDate,
                    record.date.addingTimeInterval(min(1, max(1, record.duration) / 2))
                )
                let distanceSample = HKQuantitySample(
                    type: distanceType,
                    quantity: distance,
                    start: sampleStart,
                    end: endDate
                )
                try await builder.addSamples([distanceSample])
            }

            try await builder.endCollection(at: endDate)
            guard let workout = try await builder.finishWorkout() else {
                throw HealthKitError.operationFailed
            }

            if let previousWorkoutUUID, previousWorkoutUUID != workout.uuid {
                try? await deleteWorkout(with: previousWorkoutUUID)
            }

            return workout.uuid
        } catch {
            builder.discardWorkout()
            throw error
        }
    }

    func deleteWorkout(with uuid: UUID?) async throws {
        guard let uuid, HKHealthStore.isHealthDataAvailable() else { return }

        let predicate = HKQuery.predicateForObject(with: uuid)
        let objects = try await samples(
            of: workoutType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: nil
        )
        guard !objects.isEmpty else { return }

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            healthStore.delete(objects) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitError.operationFailed)
                }
            }
        }
    }

    private func refreshAccessState() {
        guard HKHealthStore.isHealthDataAvailable() else {
            accessState = .unavailable
            return
        }

        switch healthStore.authorizationStatus(for: workoutType) {
        case .sharingAuthorized:
            accessState = .connected
        case .sharingDenied:
            accessState = .denied
        case .notDetermined:
            accessState = .notConnected
        @unknown default:
            accessState = .notConnected
        }
    }

    private func fetchLatestBodyMass() async throws -> Double? {
        let sort = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )
        let results = try await samples(
            of: bodyMassType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sort]
        )
        guard let sample = results.first as? HKQuantitySample else { return nil }
        return sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
    }

    private func samples(
        of type: HKSampleType,
        predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            healthStore.execute(query)
        }
    }

}

private enum HealthKitError: Error {
    case operationFailed
}

private extension WorkoutRecord {
    var hasTrainingData: Bool {
        exercises.contains { !$0.sets.isEmpty }
            || cardioEntries.contains { $0.durationMinutes > 0 }
    }

    var healthActivityType: HKWorkoutActivityType {
        if exercises.contains(where: { !$0.sets.isEmpty }) {
            return .traditionalStrengthTraining
        }

        switch cardioEntries.sorted(by: { $0.order < $1.order }).first?.kind {
        case .treadmillWalk:
            return .walking
        case .treadmillRun:
            return .running
        case .cycling:
            return .cycling
        case .elliptical:
            return .elliptical
        case .rowing:
            return .rowing
        case .other, .none:
            return .other
        }
    }

    var healthDistance: HKQuantity? {
        let kilometers = cardioEntries.reduce(0) {
            $0 + max(0, $1.distanceKilometers)
        }
        guard kilometers > 0 else { return nil }
        return HKQuantity(
            unit: .meterUnit(with: .kilo),
            doubleValue: kilometers
        )
    }

    var healthDistanceType: HKQuantityType? {
        switch cardioEntries.sorted(by: { $0.order < $1.order }).first?.kind {
        case .treadmillWalk, .treadmillRun:
            return HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
        case .cycling:
            return HKObjectType.quantityType(forIdentifier: .distanceCycling)
        case .rowing:
            if #available(iOS 18.0, *) {
                return HKObjectType.quantityType(forIdentifier: .distanceRowing)
            }
            return nil
        case .elliptical, .other, .none:
            return nil
        }
    }
}
