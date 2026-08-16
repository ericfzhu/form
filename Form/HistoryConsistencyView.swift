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
        VStack(alignment: .leading, spacing: 18) {
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
            InkDivider()
            HStack(alignment: .firstTextBaseline) {
                Text("12-WEEK CONSISTENCY")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(InkPalette.softInk)
                Spacer()
                Text("\(activeWeekCount) active · \(twelveWeekSessionCount) sessions")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(InkPalette.softInk)
            }
            HStack(alignment: .bottom, spacing: 7) {
                ForEach(weeklyCounts) { week in
                    Rectangle()
                        .fill(week.count > 0 ? InkPalette.cinnabar : InkPalette.washedInk.opacity(0.58))
                        .frame(height: week.count == 0 ? 5 : min(42, 10 + Double(week.count) * 9))
                        .frame(maxWidth: .infinity, alignment: .bottom)
                        .accessibilityLabel("Week of \(week.id.formatted(date: .abbreviated, time: .omitted)), \(week.count) sessions")
                }
            }
            .frame(height: 48, alignment: .bottom)
        }
        .padding(15)
        .inkCard()
    }

    private var calendarHeader: some View {
        HStack {
            Button { changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            Spacer()
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.system(.headline, design: .serif, weight: .semibold))
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
            .foregroundStyle(count > 0 ? InkPalette.raisedPaper : InkPalette.softInk)
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(count > 0 ? InkPalette.cinnabar : Color.clear)
            .overlay { Rectangle().stroke(InkPalette.bronze.opacity(0.36), lineWidth: 0.5) }
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

