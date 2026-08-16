import Foundation
import Testing
@testable import FormCore

@Test func mixedCardioReceivesSeparateValidSampleWindows() {
    let windows = HealthDistanceWindowPlanner.plan(
        entryDurations: [1_800, 1_200],
        workoutDuration: 3_600
    )

    #expect(windows.count == 2)
    #expect(windows[0] == HealthDistanceWindow(startOffset: 0, endOffset: 1_800))
    #expect(windows[1] == HealthDistanceWindow(startOffset: 1_800, endOffset: 3_000))
}

@Test func shortWorkoutStillProducesPositiveWindowsForEveryEntry() {
    let windows = HealthDistanceWindowPlanner.plan(
        entryDurations: [60, 60, 60],
        workoutDuration: 1
    )

    #expect(windows.count == 3)
    #expect(windows.allSatisfy { $0.endOffset > $0.startOffset })
    #expect(windows.allSatisfy { $0.startOffset >= 0 && $0.endOffset <= 1 })
}
