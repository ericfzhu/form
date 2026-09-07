import Foundation
import Testing
@testable import FormCore

@Test func gymInventoryIsLoadedAndIdentifiersAreUnique() {
    #expect(PlanningCatalog.exercises.count >= 27)
    #expect(Set(PlanningCatalog.exercises.map(\.id)).count == PlanningCatalog.exercises.count)
}

@Test func providedGymNeverAssumesDumbbellsOrLegPress() {
    let profile = GymProfile()
    #expect(!profile.equipment.contains(.dumbbells))
    #expect(!profile.equipment.contains(.legPress))
    let sessions = WorkoutPlanner.sessions(for: profile)
    #expect(sessions.count == 3)
    #expect(sessions.allSatisfy { $0.missing.isEmpty })
    for movement in sessions.flatMap(\.movements) {
        #expect(movement.exercise.equipment.isSubset(of: profile.effectiveEquipment))
    }
    #expect(sessions[0].movements.contains { $0.id == "barbell-bench-press" })
}

@Test func rackAndBenchCannotStandInForABarbell() {
    var profile = GymProfile()
    profile.equipment = [.rack, .bench]
    let options = WorkoutPlanner.available(in: profile)
    #expect(!options.contains { $0.id == "barbell-back-squat" })
    #expect(!options.contains { $0.id == "barbell-bench-press" })
}

@Test func adjustableBenchSatisfiesFlatBenchRequirement() {
    var profile = GymProfile()
    profile.equipment = [.dumbbells, .adjustableBench]
    #expect(WorkoutPlanner.available(in: profile).contains { $0.id == "chest-press" })
    #expect(WorkoutPlanner.available(in: profile).contains { $0.id == "incline-press" })
    profile.equipment = [.dumbbells, .bench]
    #expect(!WorkoutPlanner.available(in: profile).contains { $0.id == "incline-press" })
}

@Test func missingPullIsExplicitWithoutEquipment() {
    var profile = GymProfile()
    profile.equipment = []
    for session in WorkoutPlanner.sessions(for: profile) {
        #expect(session.missing.contains(.pull))
        #expect(session.movements.allSatisfy { $0.exercise.equipment.isEmpty })
        #expect(!session.movements.isEmpty)
    }
}

@Test func swapsCannotBypassEquipmentOrMovementRequirements() {
    var profile = GymProfile()
    profile.equipment = [.barbell, .rack, .bench]
    profile.overrides = ["plan-1-push": "incline-press", "plan-1-squat": "barbell-row"]
    let session = WorkoutPlanner.sessions(for: profile)[0]
    #expect(!session.movements.contains { $0.id == "incline-press" })
    #expect(session.movements.first?.exercise.pattern == .squat)
    profile.overrides["plan-1-push"] = "pushup"
    #expect(WorkoutPlanner.sessions(for: profile)[0].movements.contains { $0.id == "pushup" })
}

@Test func cardioMachinesDoNotBecomeStrengthEquipment() {
    var profile = GymProfile()
    profile.equipment = [.bike, .elliptical, .rower, .treadmill]
    #expect(WorkoutPlanner.available(in: profile).allSatisfy { $0.equipment.isEmpty })
}

@Test func timeBudgetsAndTargetsRemainSensible() {
    for minutes in [30, 45, 60] {
        for focus in TrainingFocus.allCases {
            var profile = GymProfile()
            profile.equipment = Set(GymEquipment.allCases)
            profile.minutes = minutes
            profile.focus = focus
            for session in WorkoutPlanner.sessions(for: profile) {
                #expect(session.estimatedMinutes <= minutes)
                #expect(Set(session.movements.map(\.id)).count == session.movements.count)
                #expect(session.movements.allSatisfy { $0.minimum <= $0.maximum && $0.sets >= 2 && $0.restSeconds >= 60 })
            }
        }
    }
}

@Test func gymProfileAndOverridesRoundTrip() throws {
    var profile = GymProfile()
    profile.configured = true
    profile.overrides["plan-1-push"] = "pushup"
    let restored = try JSONDecoder().decode(GymProfile.self, from: JSONEncoder().encode(profile))
    #expect(restored == profile)
    #expect(WorkoutPlanner.sessions(for: restored) == WorkoutPlanner.sessions(for: profile))
}
