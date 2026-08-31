import Foundation
import SwiftUI

struct HistoryConsistencyView: View {
    let workouts: [WorkoutRecord]
    @State private var displayedMonth = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: Date())
    ) ?? Date()
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private var calendar: Calendar { .current }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RecordSectionHeading(
                title: "Consistency",
                detail: "\(activeWeekCount) ACTIVE · \(twelveWeekSessionCount) SESSIONS"
            )
            calendarHeader
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(InkPalette.softInk.opacity(0.74))
                }
            }
            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(monthCells) { cell in dayCell(cell.date) }
            }
            Text("TWELVE WEEKS")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(InkPalette.softInk.opacity(0.72))
            HStack(alignment: .bottom, spacing: 7) {
                ForEach(weeklyCounts) { week in
                    weekMark(week)
                }
            }
            .frame(height: 48, alignment: .bottom)
        }
        .padding(.horizontal, 7)
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) { InkDivider().opacity(0.38) }
    }

    private func weekMark(_ week: WeekCount) -> some View {
        let height: CGFloat = week.count == 0
            ? 5
            : min(42, CGFloat(10 + week.count * 9))
        let color = week.count > 0
            ? InkPalette.cinnabar
            : InkPalette.washedInk.opacity(0.58)
        let angle = Double(week.count % 3) - 1

        return Rectangle()
            .fill(color)
            .frame(width: 2, height: height)
            .frame(maxWidth: .infinity, alignment: .bottom)
            .rotationEffect(.degrees(angle))
            .accessibilityLabel(
                "Week of \(week.id.formatted(date: .abbreviated, time: .omitted)), \(week.count) sessions"
            )
    }

    private var calendarHeader: some View {
        HStack {
            Button { changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            Spacer()
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(AtelierType.script(20))
            Spacer()
            Button { changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }
            .disabled(isCurrentMonth)
            .opacity(isCurrentMonth ? 0.24 : 1)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func dayCell(_ date: Date?) -> some View {
        let count = date.map(sessionCount(on:)) ?? 0
        return Text(date?.formatted(.dateTime.day()) ?? "")
            .font(.caption.monospacedDigit().weight(count > 0 ? .semibold : .regular))
            .foregroundStyle(count > 0 ? InkPalette.mineral : InkPalette.softInk)
            .frame(maxWidth: .infinity, minHeight: 38)
            .background {
                if count > 0 {
                    Circle()
                        .trim(from: 0.05, to: 0.86)
                        .stroke(InkPalette.mineral, style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                        .rotationEffect(.degrees(-30))
                        .frame(width: 31, height: 31)
                }
            }
            .accessibilityHidden(date == nil)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = max(0, calendar.firstWeekday - 1)
        return Array(symbols[offset...] + symbols[..<offset])
    }

    private var monthCells: [CalendarCell] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return []
        }
        let leading = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        var cells = (0..<leading).map { CalendarCell(id: $0, date: nil) }
        cells += range.map { day in
            CalendarCell(
                id: leading + day - 1,
                date: calendar.date(byAdding: .day, value: day - 1, to: first)
            )
        }
        return cells
    }

    private var weeklyCounts: [WeekCount] {
        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else {
            return []
        }
        return (0..<12).reversed().compactMap { offset in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeek),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { return nil }
            return WeekCount(
                id: start,
                count: workouts.filter { $0.date >= start && $0.date < end }.count
            )
        }
    }

    private var activeWeekCount: Int { weeklyCounts.filter { $0.count > 0 }.count }
    private var twelveWeekSessionCount: Int { weeklyCounts.reduce(0) { $0 + $1.count } }
    private var isCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    private func sessionCount(on date: Date) -> Int {
        workouts.filter { calendar.isDate($0.date, inSameDayAs: date) }.count
    }

    private func changeMonth(by value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: displayedMonth),
              next <= Date() else { return }
        withAnimation(.easeOut(duration: 0.2)) { displayedMonth = next }
    }

    private struct CalendarCell: Identifiable { let id: Int; let date: Date? }
    private struct WeekCount: Identifiable { let id: Date; let count: Int }
}
