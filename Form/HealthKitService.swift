import Combine
import Foundation
import HealthKit

enum HealthAccessState: Equatable {
    case unavailable
    case notConnected
    case connected
    case denied
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

        if accessState == .connected {
            await refresh()
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
        from payload: HealthWorkoutPayload,
        replacing previousWorkoutUUID: UUID? = nil
    ) async throws -> UUID? {
        guard canWriteWorkouts, payload.hasTrainingData else { return nil }

        let loggedCardioDuration = payload.cardio.reduce(0) {
            $0 + max(0, $1.durationMinutes * 60)
        }
        let endDate = payload.startedAt.addingTimeInterval(
            max(1, payload.duration, loggedCardioDuration)
        )
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = payload.healthActivityType
        configuration.locationType = .indoor

        var replacedUUIDs = Set(
            try await workouts(withExternalIdentifier: payload.syncIdentifier)
                .map(\.uuid)
        )
        if let previousWorkoutUUID {
            replacedUUIDs.insert(previousWorkoutUUID)
        }

        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: .local()
        )

        do {
            try await builder.beginCollection(at: payload.startedAt)
            try await builder.addMetadata([
                HKMetadataKeyIndoorWorkout: true,
                HKMetadataKeyExternalUUID: payload.syncIdentifier.uuidString
            ])

            let samples = distanceSamples(for: payload, workoutEnd: endDate)
            if !samples.isEmpty {
                try await builder.addSamples(samples)
            }

            try await builder.endCollection(at: endDate)
            guard let workout = try await builder.finishWorkout() else {
                throw HealthKitError.operationFailed
            }

            for replacedUUID in replacedUUIDs where replacedUUID != workout.uuid {
                try await deleteWorkout(with: replacedUUID)
            }

            return workout.uuid
        } catch {
            builder.discardWorkout()
            throw error
        }
    }

    func deleteWorkout(
        with uuid: UUID?,
        externalIdentifier: UUID? = nil
    ) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let predicate: NSPredicate?
        if let uuid {
            predicate = HKQuery.predicateForObject(with: uuid)
        } else if let externalIdentifier {
            predicate = HKQuery.predicateForObjects(
                withMetadataKey: HKMetadataKeyExternalUUID,
                allowedValues: [externalIdentifier.uuidString]
            )
        } else {
            return
        }

        let objects = try await samples(
            of: workoutType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        )
        guard !objects.isEmpty else { return }
        try await delete(objects)
    }

    private func workouts(
        withExternalIdentifier identifier: UUID
    ) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyExternalUUID,
            allowedValues: [identifier.uuidString]
        )
        return try await samples(
            of: workoutType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ).compactMap { $0 as? HKWorkout }
    }

    private func distanceSamples(
        for payload: HealthWorkoutPayload,
        workoutEnd: Date
    ) -> [HKQuantitySample] {
        let eligible = payload.cardio.compactMap {
            entry -> (HealthCardioPayload, HKQuantityType)? in
            guard entry.distanceKilometers > 0,
                  let type = distanceType(for: entry.kind),
                  healthStore.authorizationStatus(for: type) == .sharingAuthorized else {
                return nil
            }
            return (entry, type)
        }
        let windows = HealthDistanceWindowPlanner.plan(
            entryDurations: eligible.map { max(1, $0.0.durationMinutes * 60) },
            workoutDuration: workoutEnd.timeIntervalSince(payload.startedAt)
        )

        return zip(eligible, windows).map { item, window in
            HKQuantitySample(
                type: item.1,
                quantity: HKQuantity(
                    unit: .meterUnit(with: .kilo),
                    doubleValue: item.0.distanceKilometers
                ),
                start: payload.startedAt.addingTimeInterval(window.startOffset),
                end: payload.startedAt.addingTimeInterval(window.endOffset)
            )
        }
    }

    private func distanceType(for kind: CardioKind) -> HKQuantityType? {
        switch kind {
        case .treadmillWalk, .treadmillRun:
            return HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
        case .cycling:
            return HKObjectType.quantityType(forIdentifier: .distanceCycling)
        case .rowing:
            if #available(iOS 18.0, *) {
                return HKObjectType.quantityType(forIdentifier: .distanceRowing)
            }
            return nil
        case .elliptical, .other:
            return nil
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

    private func delete(_ objects: [HKObject]) async throws {
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
}

private enum HealthKitError: Error {
    case operationFailed
}

private extension HealthWorkoutPayload {
    var healthActivityType: HKWorkoutActivityType {
        if hasStrengthTraining {
            return .traditionalStrengthTraining
        }

        switch cardio.first?.kind {
        case .treadmillWalk: return .walking
        case .treadmillRun: return .running
        case .cycling: return .cycling
        case .elliptical: return .elliptical
        case .rowing: return .rowing
        case .other, .none: return .other
        }
    }
}
