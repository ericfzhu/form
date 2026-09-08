import XCTest
@testable import FormCore

final class LiveWorkoutStateTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func state(restEnd: Date? = nil) -> LiveWorkoutState {
        LiveWorkoutState(completedMovements: 1, totalMovements: 4,
            currentExercise: "Barbell bench press", restEnd: restEnd,
            sessionTimerStartedAt: now.addingTimeInterval(-720), pausedDuration: 720)
    }

    func testRestTransitionsAtDeadlineWithoutAppUpdate() {
        let end = now.addingTimeInterval(60)
        let value = state(restEnd: end)
        XCTAssertEqual(value.phase(at: now), .resting)
        XCTAssertEqual(value.phase(at: end), .ready)
        XCTAssertEqual(value.phase(at: end.addingTimeInterval(600)), .ready)
        XCTAssertEqual(value.phase(at: now, isStale: true), .ready)
    }

    func testExplicitDeadlineRefreshShowsReady() {
        var value = state(restEnd: now.addingTimeInterval(1))
        value.restFinished = true
        XCTAssertEqual(value.phase(at: now), .ready)
    }

    func testPausedWinsOverRestAndWalk() {
        var value = state(restEnd: now.addingTimeInterval(60))
        value.sessionTimerStartedAt = nil
        XCTAssertEqual(value.phase(at: now), .paused)
        value.isWalk = true
        XCTAssertEqual(value.phase(at: now), .paused)
    }

    func testWalkingUsesItsOwnPhaseEvenAfterOldRestDeadline() {
        var value = state(restEnd: now.addingTimeInterval(-1))
        value.isWalk = true
        value.walkTimerStartedAt = now.addingTimeInterval(-300)
        XCTAssertEqual(value.phase(at: now, isStale: true), .walking)
        XCTAssertNotEqual(value.sessionTimerStartedAt, value.walkTimerStartedAt)
    }

    func testLiftingDoesNotBecomeReadyMerelyBecauseContentIsStale() {
        XCTAssertEqual(state().phase(at: now, isStale: true), .lifting)
    }

    func testExistingActivityPayloadStillDecodes() throws {
        let old = """
        {"completedMovements":1,"totalMovements":4,"currentExercise":"Bench press","sessionTimerStartedAt":100,"pausedDuration":42}
        """
        let value = try JSONDecoder().decode(LiveWorkoutState.self, from: Data(old.utf8))
        XCTAssertNil(value.walkTimerStartedAt)
        XCTAssertNil(value.exerciseArtwork)
        XCTAssertEqual(value.phase(at: now), .lifting)
    }

    func testProgressNeverReportsNegativeOrExcessCounts() {
        var value = state()
        value.completedMovements = 8
        XCTAssertEqual(value.progress, "4 of 4 exercises done")
        value.totalMovements = -1
        XCTAssertEqual(value.progress, "0 of 0 exercises done")
    }

    func testSessionLinkValidatesSchemeHostAndPath() {
        let id = UUID()
        XCTAssertEqual(LiveWorkoutState.sessionID(from: URL(string: "form://session/\(id)")!), id)
        for url in ["https://session/\(id)", "form://other/\(id)", "form://session/nope", "form://session/\(id)/extra"] {
            XCTAssertNil(LiveWorkoutState.sessionID(from: URL(string: url)!))
        }
    }

    func testWalkSurvivesPersistenceAndCountsBackgroundTime() throws {
        let walk = TimedWalk(now: now)
        let restored = try JSONDecoder().decode(TimedWalk.self, from: JSONEncoder().encode(walk))
        XCTAssertEqual(restored.id, walk.id)
        XCTAssertEqual(restored.elapsed(at: now.addingTimeInterval(372)), 372)
        XCTAssertEqual(restored.timerStartedAt, now)
    }

    func testWalkPauseResumeDoesNotCountPausedTimeOrDoubleCount() {
        var walk = TimedWalk(now: now)
        walk.pause(at: now.addingTimeInterval(60))
        walk.pause(at: now.addingTimeInterval(100))
        XCTAssertEqual(walk.elapsed(at: now.addingTimeInterval(200)), 60)
        XCTAssertNil(walk.timerStartedAt)
        walk.resume(at: now.addingTimeInterval(300))
        walk.resume(at: now.addingTimeInterval(330))
        XCTAssertEqual(walk.elapsed(at: now.addingTimeInterval(360)), 120)
        XCTAssertEqual(walk.timerStartedAt, now.addingTimeInterval(240))
    }
}
