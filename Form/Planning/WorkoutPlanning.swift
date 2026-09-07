import Foundation

// The website and iOS app use this same exercise inventory.
enum GymEquipment: String, Codable, CaseIterable, Identifiable {
    case dumbbells, bench, adjustableBench, barbell, rack, cable, highLow, pulldown, legPress, legCurl, bike, elliptical, rower, treadmill
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dumbbells: "Dumbbells"
        case .bench: "Flat bench"
        case .adjustableBench: "Adjustable bench"
        case .barbell: "Barbell & plates"
        case .rack: "Squat rack"
        case .cable: "Cable row station"
        case .pulldown: "Lat pulldown"
        case .legPress: "Leg press"
        case .legCurl: "Seated leg curl"
        case .highLow: "High–low pulley"
        case .bike: "Upright bike"
        case .elliptical: "Elliptical"
        case .rower: "Rowing machine"
        case .treadmill: "Treadmill"
        }
    }
    var isCardio: Bool { [.bike, .elliptical, .rower, .treadmill].contains(self) }
    static func effective(_ equipment: Set<GymEquipment>) -> Set<GymEquipment> {
        equipment.contains(.adjustableBench) ? equipment.union([.bench]) : equipment
    }
}

enum TrainingFocus: String, Codable, CaseIterable, Identifiable {
    case strength, muscle, consistency
    var id: String { rawValue }
    var title: String {
        switch self { case .strength: "Build strength"; case .muscle: "Build muscle"; case .consistency: "Find a rhythm" }
    }
}

struct GymProfile: Codable, Equatable {
    var name = "My gym"
    var equipment: Set<GymEquipment> = [.barbell, .rack, .adjustableBench, .legCurl, .highLow, .pulldown, .cable, .bike, .elliptical, .rower, .treadmill]
    var sessionsPerWeek = 3
    var minutes = 45
    var focus: TrainingFocus = .consistency
    var configured = false
    var overrides: [String: String] = [:]
    var effectiveEquipment: Set<GymEquipment> { GymEquipment.effective(equipment) }
}

enum MovementPattern: String, Codable, CaseIterable {
    case squat, hinge, push, pull, singleLeg, core, carry, accessory
    var title: String {
        switch self {
        case .singleLeg: "Single leg"
        case .accessory: "Leg accessory"
        default: rawValue.capitalized
        }
    }
}

struct PlanningExercise: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let pattern: MovementPattern
    let equipment: Set<GymEquipment>
    let measurement: String
    func isAvailable(in profile: GymProfile) -> Bool { equipment.isSubset(of: profile.effectiveEquipment) }
}

struct PlannedMovement: Identifiable, Equatable {
    let exercise: PlanningExercise
    let sets: Int
    let minimum: Int
    let maximum: Int
    let restSeconds: Int
    var id: String { exercise.id }
    var target: String { "\(sets) × \(minimum)–\(maximum)\(exercise.measurement.contains("Timed") || exercise.measurement == "timed" ? " sec" : " reps")" }
}

struct PlannedSession: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let movements: [PlannedMovement]
    let missing: [MovementPattern]
    let minutes: Int
    var estimatedMinutes: Int {
        // Includes a 5 minute allowance; estimates, not a time guarantee.
        5 + Int(ceil(Double(movements.reduce(0) { $0 + $1.sets * (45 + $1.restSeconds) }) / 60))
    }
}

enum PlanningCatalog {
    static let exercises: [PlanningExercise] = {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "exercises", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let result = try? JSONDecoder().decode([PlanningExercise].self, from: data) else { return [] }
        return result
    }()
}

enum WorkoutPlanner {
    static func available(in profile: GymProfile, pattern: MovementPattern? = nil) -> [PlanningExercise] {
        PlanningCatalog.exercises.filter { $0.isAvailable(in: profile) && (pattern == nil || $0.pattern == pattern) }
            .sorted { !$0.equipment.isEmpty && $1.equipment.isEmpty }
    }

    static func sessions(for profile: GymProfile) -> [PlannedSession] {
        let count = min(4, max(2, profile.sessionsPerWeek))
        return (0..<count).map { index in
            let id = "plan-\(index + 1)"
            var patterns: [MovementPattern] = index.isMultiple(of: 2)
                ? [.squat, .push, .pull, .hinge] : [.hinge, .pull, .push, .singleLeg]
            if profile.minutes == 30 { patterns.removeLast() }
            if profile.minutes >= 45 { patterns.append(.core) }
            if profile.minutes >= 60 { patterns.append(available(in: profile, pattern: .accessory).isEmpty ? .carry : .accessory) }
            var missing: [MovementPattern] = []
            var movements: [PlannedMovement] = patterns.compactMap { pattern in
                let options = available(in: profile, pattern: pattern)
                guard !options.isEmpty else { missing.append(pattern); return nil }
                let chosen = options.first { $0.id == profile.overrides["\(id)-\(pattern.rawValue)"] }
                    ?? options[min(index % 2, options.count - 1)]
                let timed = chosen.measurement == "timed" || chosen.measurement == "weightedTimed"
                let strength = profile.focus == .strength && chosen.measurement == "weighted"
                return PlannedMovement(exercise: chosen,
                    sets: profile.minutes == 30 || profile.focus == .consistency ? 2 : 3,
                    minimum: timed ? 30 : (strength ? 6 : 8),
                    maximum: timed ? 45 : (strength ? 8 : 12),
                    restSeconds: timed ? 60 : (strength ? 150 : 90))
            }
            // Keep prescribed rest; reduce extra sets if the time budget is tight.
            for i in movements.indices.reversed() {
                let estimated = 5 + Int(ceil(Double(movements.reduce(0) { $0 + $1.sets * (45 + $1.restSeconds) }) / 60))
                if estimated <= profile.minutes { break }
                let m = movements[i]
                if m.sets > 2 {
                    movements[i] = PlannedMovement(exercise: m.exercise, sets: 2, minimum: m.minimum,
                        maximum: m.maximum, restSeconds: m.restSeconds)
                }
            }
            return PlannedSession(id: id, name: "Session \(index + 1)",
                subtitle: index.isMultiple(of: 2) ? "Squat, push & pull" : "Hinge, pull & single leg",
                movements: movements, missing: missing, minutes: profile.minutes)
        }
    }
}
