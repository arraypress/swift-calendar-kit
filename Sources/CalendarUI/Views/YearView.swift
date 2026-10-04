//
//  YearView.swift
//  CalendarUI
//

import SwiftUI

/// A year of small months. Days with events take the first event's colour;
/// tapping a month hands it back so you can switch to the month view.
public struct YearView<Event: CalendarEvent>: View {

    @Environment(\.calendarStyle) private var style
    @Binding private var date: Date
    private let events: [Event]
    private let calendar: Calendar
    private let tint: (Event) -> Color
    private let onSelectMonth: ((Date) -> Void)?

    /// A year view for the year containing `date`.
    public init(
        events: [Event], date: Binding<Date>, calendar: Calendar = .current,
        tint: @escaping (Event) -> Color = { _ in .accentColor }, onSelectMonth: ((Date) -> Void)? = nil
    ) {
        _date = date
        self.events = events
        self.calendar = calendar
        self.tint = tint
        self.onSelectMonth = onSelectMonth
    }

    public var body: some View {
        let months = Timetable.year(containing: date, calendar: calendar, rows: .six)
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(calendar.yearTitle(date))
                    .font(.title2.weight(.bold))
                Spacer()
                StepButton(systemImage: "chevron.left") { move(by: -1) }
                StepButton(systemImage: "chevron.right") { move(by: 1) }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            Divider()
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 20)], spacing: 20) {
                    ForEach(months) { month in
                        MiniMonth(month: month)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                date = month.month.start
                                onSelectMonth?(month.month.start)
                            }
                    }
                }
                .padding()
            }
        }
    }

    private func MiniMonth(month: MonthGrid) -> some View {
        let perDay = Timetable.events(events, on: month.days.map(\.date), calendar: calendar)
        let current = calendar.isDate(month.month.start, equalTo: .now, toGranularity: .month)
        return VStack(alignment: .leading, spacing: 6) {
            Text(calendar.monthName(month.month.start))
                .font(.headline)
                .foregroundStyle(current ? style.todayColor : .primary)
            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                ForEach(Array(month.weeks.enumerated()), id: \.offset) { row, week in
                    GridRow {
                        ForEach(Array(week.enumerated()), id: \.element.id) { column, day in
                            let first = perDay[row * 7 + column].first
                            let today = calendar.isToday(day.date)
                            Text(calendar.dayNumber(day.date))
                                .font(.system(size: 9, weight: first == nil ? .regular : .bold))
                                .monospacedDigit()
                                .foregroundStyle(today ? AnyShapeStyle(.white) : first.map { AnyShapeStyle(tint($0)) } ?? AnyShapeStyle(.primary))
                                .frame(maxWidth: .infinity, minHeight: 16)
                                .background { if today { Circle().fill(style.todayColor) } }
                                .opacity(day.isInMonth ? 1 : 0)
                        }
                    }
                }
            }
        }
    }

    private func move(by years: Int) {
        withAnimation(.snappy) {
            date = calendar.date(byAdding: .year, value: years, to: date) ?? date
        }
    }
}
