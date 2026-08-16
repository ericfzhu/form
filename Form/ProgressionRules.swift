import Foundation

enum ProgressionMeasurement: String, Codable {
    case weighted
    case weightedTimed
    case bodyweight
    case timed
}

struct ProgressionPrescription: Equatable {
    let measurement: ProgressionMeasurement
    let prescribedSets: Int
    let minimumRepetitions: Int
    let maximumRepetitions: Int
    let loadIncrement: Double
}

struct ProgressionInputSet: Equatable {
    let weight: Double
    let repetitions: Int
}

struct ProgressionInputPerformance: Equatable {
    let sets: [ProgressionInputSet]
}

enum ProgressionDecision: Equatable {
    case increaseLoad(Double)
    case reduceLoad(Double)
    case holdLoad(Double)
    case recordLoad
    case addRepetition
    case addTime
}

enum ProgressionRules {
    static func decision(
        prescription: ProgressionPrescription,
        performances: [ProgressionInputPerformance]
    ) -> ProgressionDecision? {
        guard let latest = performances.first else { return nil }

        switch prescription.measurement {
        case .weighted, .weightedTimed:
            let prescribed = Array(latest.sets.prefix(prescription.prescribedSets))
            guard !prescribed.isEmpty else { return nil }
            let currentLoad = prescribed.map(\.weight).max() ?? 0

            if prescription.measurement == .weightedTimed, currentLoad <= 0 {
                return .recordLoad
            }

            let reachedTopOfRange: Bool
            switch prescription.measurement {
            case .weighted:
                reachedTopOfRange = prescribed.count >= prescription.prescribedSets
                    && prescribed.allSatisfy {
                        $0.weight > 0
                            && $0.repetitions >= prescription.maximumRepetitions
                    }
            case .weightedTimed:
                reachedTopOfRange = prescribed.count >= prescription.prescribedSets
                    && prescribed.allSatisfy {
                        $0.weight == currentLoad
                            && $0.repetitions >= prescription.maximumRepetitions
                    }
            case .bodyweight, .timed:
                reachedTopOfRange = false
            }

            if reachedTopOfRange {
                return .increaseLoad(currentLoad + prescription.loadIncrement)
            }

            let repeatedShortfall = performances.prefix(2).count == 2
                && performances.prefix(2).allSatisfy { performance in
                    let sets = Array(performance.sets.prefix(prescription.prescribedSets))
                    if sets.count < prescription.prescribedSets {
                        return true
                    }
                    switch prescription.measurement {
                    case .weighted:
                        return sets.contains {
                            $0.repetitions < prescription.minimumRepetitions
                        }
                    case .weightedTimed:
                        return sets.contains {
                            $0.weight <= 0
                                || $0.repetitions < prescription.minimumRepetitions
                        }
                    case .bodyweight, .timed:
                        return false
                    }
                }

            if repeatedShortfall, currentLoad > 0 {
                return .reduceLoad(max(0, currentLoad - prescription.loadIncrement))
            }
            return .holdLoad(currentLoad)

        case .bodyweight:
            return .addRepetition
        case .timed:
            return .addTime
        }
    }
}
