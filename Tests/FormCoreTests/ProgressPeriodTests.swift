import Foundation
import Testing
@testable import FormCore

@Test func twelveWeekPeriodExcludesOlderSessions() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let end = Date(timeIntervalSince1970: 2_000_000_000)
    let recent = calendar.date(byAdding: .weekOfYear, value: -11, to: end)!
    let old = calendar.date(byAdding: .weekOfYear, value: -13, to: end)!

    #expect(ProgressPeriod.twelveWeeks.includes(recent, relativeTo: end, calendar: calendar))
    #expect(!ProgressPeriod.twelveWeeks.includes(old, relativeTo: end, calendar: calendar))
    #expect(ProgressPeriod.allTime.includes(old, relativeTo: end, calendar: calendar))
}
