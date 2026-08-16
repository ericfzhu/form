import Foundation

struct HealthDistanceWindow: Equatable {
    let startOffset: TimeInterval
    let endOffset: TimeInterval
}

enum HealthDistanceWindowPlanner {
    static func plan(
        entryDurations: [TimeInterval],
        workoutDuration: TimeInterval
    ) -> [HealthDistanceWindow] {
        let totalDuration = max(1, workoutDuration)
        let latestValidStart = max(0, totalDuration - 1)
        var cursor: TimeInterval = 0

        return entryDurations.map { requestedDuration in
            let start = min(cursor, latestValidStart)
            let end = min(
                totalDuration,
                max(start + 1, start + max(1, requestedDuration))
            )
            cursor = end
            return HealthDistanceWindow(startOffset: start, endOffset: end)
        }
    }
}
