import Foundation
import Testing
@testable import FormCore

@Test func activeDurationCountsOnlyResumedSegments() {
    let start = Date(timeIntervalSince1970: 1_000)
    var duration = ActiveDurationAccumulator(
        accumulated: 30,
        segmentStartedAt: start
    )

    #expect(duration.elapsed(at: start.addingTimeInterval(20)) == 50)
    duration.pause(at: start.addingTimeInterval(20))
    #expect(duration.elapsed(at: start.addingTimeInterval(200)) == 50)

    duration.resume(at: start.addingTimeInterval(300))
    #expect(duration.elapsed(at: start.addingTimeInterval(315)) == 65)
}

@Test func pausingTwiceDoesNotDoubleCount() {
    let start = Date(timeIntervalSince1970: 1_000)
    var duration = ActiveDurationAccumulator(segmentStartedAt: start)
    duration.pause(at: start.addingTimeInterval(10))
    duration.pause(at: start.addingTimeInterval(20))
    #expect(duration.elapsed(at: start.addingTimeInterval(30)) == 10)
}
