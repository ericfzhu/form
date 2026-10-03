import XCTest
@testable import FormCore

final class SessionObservationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testRoutineFirstEmptyAndLowerPerformanceSessionsNeedNoHighlight() {
        let previous = workout(load: 40, reps: 8, dateOffset: -3600)
        let same = workout(load: 40, reps: 8)
        let lower = workout(load: 35, reps: 6)
        XCTAssertNil(SessionObservation.message(for: same, in: [same]))
        XCTAssertNil(SessionObservation.message(for: same, in: [same, previous]))
        XCTAssertNil(SessionObservation.message(for: lower, in: [lower, previous]))
        same.exercises = []
        XCTAssertNil(SessionObservation.message(for: same, in: [same, previous]))
    }

    func testLoadHighlightRequiresExceedingAllEarlierWorkingSets() {
        let oldBest = workout(load: 50, reps: 6, dateOffset: -7200)
        let previous = workout(load: 40, reps: 8, dateOffset: -3600)
        let current = workout(load: 45, reps: 8)
        XCTAssertNil(SessionObservation.message(for: current, in: [current, previous, oldBest]))
        current.exercises[0].sets[0].weight = 55
        XCTAssertEqual(SessionObservation.message(for: current, in: [current, previous, oldBest]),
                       "Barbell bench press: your heaviest recorded load, 55 kg.")
    }

    func testRepetitionComparisonUsesSameLoadFromLastSession() {
        let oldBest = workout(load: 60, reps: 6, dateOffset: -7200)
        let previous = workout(load: 40, reps: 8, dateOffset: -3600)
        let current = workout(load: 40, reps: 10)
        XCTAssertEqual(SessionObservation.message(for: current, in: [current, previous, oldBest]),
                       "Barbell bench press: 2 more reps at 40 kg than last session.")
        previous.exercises[0].sets[0].weight = 45
        XCTAssertNil(SessionObservation.message(for: current, in: [current, previous, oldBest]))
    }

    func testWarmupsAndFutureRecordsDoNotAffectHighlight() {
        let previous = workout(load: 40, reps: 8, dateOffset: -3600)
        previous.exercises[0].sets.append(SetRecord(order: 1, weight: 100, repetitions: 1, kind: .warmup))
        let current = workout(load: 45, reps: 8)
        let future = workout(load: 100, reps: 8, dateOffset: 3600)
        XCTAssertEqual(SessionObservation.message(for: current, in: [current, future, previous]),
                       "Barbell bench press: your heaviest recorded load, 45 kg.")
        current.exercises[0].sets[0].kind = .warmup
        XCTAssertNil(SessionObservation.message(for: current, in: [current, previous]))
    }

    func testCardioHighlightRequiresPreviousEntryOfTheSameKind() {
        let previous = workout(load: 0, reps: 0, dateOffset: -3600)
        previous.cardioEntries = [CardioRecord(kind: .treadmillWalk, order: 0, durationMinutes: 15)]
        let current = workout(load: 0, reps: 0)
        current.cardioEntries = [CardioRecord(kind: .treadmillWalk, order: 0, durationMinutes: 20)]
        XCTAssertEqual(SessionObservation.message(for: current, in: [current, previous]),
                       "Treadmill walk: your longest recorded entry, 20 min.")
        current.cardioEntries[0].kind = .cycling
        XCTAssertNil(SessionObservation.message(for: current, in: [current, previous]))
    }

    private func workout(load: Double, reps: Int, dateOffset: TimeInterval = 0) -> WorkoutRecord {
        let exercise = ExerciseRecord(exerciseID: "barbell-bench-press", name: "Barbell bench press",
                                      assetName: "barbell-bench-press", order: 0)
        exercise.sets = [SetRecord(order: 0, weight: load, repetitions: reps)]
        return WorkoutRecord(date: now.addingTimeInterval(dateOffset), routineName: "Full-body A",
                             duration: 1200, exercises: [exercise])
    }
}
