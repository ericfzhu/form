import Foundation

struct ActiveDurationAccumulator: Equatable {
    private(set) var accumulated: TimeInterval
    private(set) var segmentStartedAt: Date?

    init(accumulated: TimeInterval = 0, segmentStartedAt: Date? = nil) {
        self.accumulated = max(0, accumulated)
        self.segmentStartedAt = segmentStartedAt
    }

    func elapsed(at date: Date = Date()) -> TimeInterval {
        accumulated + (segmentStartedAt.map {
            max(0, date.timeIntervalSince($0))
        } ?? 0)
    }

    var timerStartedAt: Date? {
        segmentStartedAt?.addingTimeInterval(-accumulated)
    }

    mutating func resume(at date: Date = Date()) {
        guard segmentStartedAt == nil else { return }
        segmentStartedAt = date
    }

    mutating func pause(at date: Date = Date()) {
        guard let segmentStartedAt else { return }
        accumulated += max(0, date.timeIntervalSince(segmentStartedAt))
        self.segmentStartedAt = nil
    }
}
