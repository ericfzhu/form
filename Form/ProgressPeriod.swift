import Foundation

enum ProgressPeriod: String, CaseIterable, Identifiable, Codable {
    case twelveWeeks
    case sixMonths
    case oneYear
    case allTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .twelveWeeks: "12 weeks"
        case .sixMonths: "6 months"
        case .oneYear: "1 year"
        case .allTime: "All time"
        }
    }

    var headerTitle: String { title.uppercased() }

    func includes(
        _ date: Date,
        relativeTo end: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard date <= end else { return false }
        guard let start = startDate(relativeTo: end, calendar: calendar) else {
            return true
        }
        return date >= start
    }

    func startDate(
        relativeTo end: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        switch self {
        case .twelveWeeks:
            calendar.date(byAdding: .weekOfYear, value: -12, to: end)
        case .sixMonths:
            calendar.date(byAdding: .month, value: -6, to: end)
        case .oneYear:
            calendar.date(byAdding: .year, value: -1, to: end)
        case .allTime:
            nil
        }
    }
}
