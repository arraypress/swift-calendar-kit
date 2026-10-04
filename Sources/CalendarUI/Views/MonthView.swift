//
//  MonthView.swift
//  CalendarUI
//

import SwiftUI

/// How a month grid shows a day's events.
public enum MonthStyle: Sendable, Hashable {

    /// Up to ``CalendarStyle/monthPillLimit`` coloured pills per day.
    case pills

    /// One labelled pill per day, such as a day's takings.
    case labelled

    /// Calendar.app style: all-day and multi-day events as one bar across the
    /// days they cover, timed events listed under each date with their time,
    /// and "+2 more" when a day overflows. Needs a `title`.
    case titles
}

/// A month grid: weekday names, whole weeks, and each day's events as pills.
public struct MonthView<Event: CalendarEvent>: View {

    @Environment(\.calendarStyle) private var style
    @Binding private var date: Date
    private let events: [Event]
    private let calendar: Calendar
    private let monthStyle: MonthStyle
    private let tint: (Event) -> Color
    private let label: (Date, [Event]) -> String?
    private let title: (Event) -> String
    private let onSelectDay: ((Date) -> Void)?

    /// A month view.
    ///
    /// - Parameters:
    ///   - date: the selected day; the grid shows its month.
    ///   - label: for ``MonthStyle/labelled``, the text in a day's pill, or
    ///     `nil` for no pill. Gets the day and its events.
    ///   - title: for ``MonthStyle/titles``, an event's title.
    public init(
        events: [Event], date: Binding<Date>, calendar: Calendar = .current, style: MonthStyle = .pills,
        tint: @escaping (Event) -> Color = { _ in .accentColor },
        label: @escaping (Date, [Event]) -> String? = { _, _ in nil },
        title: @escaping (Event) -> String = { _ in "" },
        onSelectDay: ((Date) -> Void)? = nil
    ) {
        _date = date
        self.events = events
        self.calendar = calendar
        self.monthStyle = style
        self.tint = tint
        self.label = label
        self.title = title
        self.onSelectDay = onSelectDay
    }

    public var body: some View {
        let grid = Timetable.month(containing: date, calendar: calendar, rows: .six)
        let perDay = Timetable.events(events, on: grid.days.map(\.date), calendar: calendar)
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(calendar.monthTitle(grid.month.start))
                    .font(.title3.weight(.semibold))
                Spacer()
                StepButton(systemImage: "chevron.left") { move(by: -1) }
                StepButton(systemImage: "chevron.right") { move(by: 1) }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            HStack(spacing: 0) {
                ForEach(Timetable.weekdaySymbols(calendar: calendar, style: .short), id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 4)
            if monthStyle == .titles {
                VStack(spacing: 0) {
                    ForEach(Array(grid.weeks.enumerated()), id: \.offset) { row, week in
                        Divider()
                        TitledWeek(week, perDay: Array(perDay[(row * 7)..<(row * 7 + 7)]))
                    }
                }
            } else {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    ForEach(Array(grid.weeks.enumerated()), id: \.offset) { row, week in
                        Divider()
                        GridRow {
                            ForEach(Array(week.enumerated()), id: \.element.id) { column, day in
                                DayCell(day: day, events: perDay[row * 7 + column])
                            }
                        }
                    }
                }
            }
        }
        .swipeToStep(vertical: true, move)
    }

    private func DayCell(day: GridDay, events: [Event]) -> some View {
        Button {
            date = day.date
            onSelectDay?(day.date)
        } label: {
            VStack(spacing: 3) {
                DayNumber(day: day.date, calendar: calendar, isSelected: calendar.isDate(day.date, inSameDayAs: date), font: .subheadline)
                switch monthStyle {
                case .pills:
                    ForEach(events.prefix(style.monthPillLimit)) { event in
                        Capsule().fill(tint(event)).frame(height: 5)
                    }
                case .titles:
                    EmptyView()
                case .labelled:
                    if let text = label(day.date, events) {
                        Text(text)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity)
                            .background(Capsule().fill(events.first.map(tint) ?? .accentColor))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 3)
            .padding(.top, 4)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .top)
            .opacity(day.isInMonth ? 1 : 0.35)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Titles style

    /// Whether an event is drawn as a bar rather than listed under its day.
    private func isBar(_ event: Event) -> Bool {
        event.isAllDay || !calendar.isDate(event.start, inSameDayAs: event.end.addingTimeInterval(-1))
    }

    private var laneHeight: CGFloat { 17 }
    private var numberHeight: CGFloat { 36 }

    /// One week: day numbers, bars across the days, then each day's timed events.
    private func TitledWeek(_ week: [GridDay], perDay: [[Event]]) -> some View {
        let days = week.map(\.date)
        let barLimit = max(style.monthPillLimit - 1, 1)
        let lanes = Timetable.lanes(events.filter(isBar), across: days, calendar: calendar, maximumLanes: barLimit)
        let barsHeight = CGFloat(lanes.laneCount) * laneHeight
        return GeometryReader { geometry in
            let column = geometry.size.width / 7
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.element.id) { index, day in
                        TitledDay(day, timed: perDay[index].filter { !isBar($0) }, hiddenBars: lanes.hidden[index],
                                  barsHeight: barsHeight, lanesShown: lanes.laneCount)
                            .frame(width: column)
                    }
                }
                ForEach(lanes.bars) { bar in
                    Bar(bar)
                        .frame(width: max(column * CGFloat(bar.length) - 4, 0), height: laneHeight - 2)
                        .offset(x: column * CGFloat(bar.firstDay) + 2, y: numberHeight + CGFloat(bar.lane) * laneHeight)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(minHeight: numberHeight + CGFloat(style.monthPillLimit + 1) * laneHeight)
    }

    private func Bar(_ bar: LaneBar<Event>) -> some View {
        let leading: CGFloat = bar.continuesBefore ? 0 : 4
        let trailing: CGFloat = bar.continuesAfter ? 0 : 4
        return Text(title(bar.event))
            .font(.system(size: 10, weight: .semibold))
            .lineLimit(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(tint(bar.event), in: UnevenRoundedRectangle(
                topLeadingRadius: leading, bottomLeadingRadius: leading,
                bottomTrailingRadius: trailing, topTrailingRadius: trailing, style: .continuous))
    }

    private func TitledDay(_ day: GridDay, timed: [Event], hiddenBars: Int, barsHeight: CGFloat, lanesShown: Int) -> some View {
        let lines = max(style.monthPillLimit + 1 - lanesShown, 1)
        let overflow = timed.count + hiddenBars > lines
        let shown = overflow ? max(lines - 1, 0) : timed.count
        let hidden = timed.count - shown + hiddenBars
        return Button {
            date = day.date
            onSelectDay?(day.date)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                DayNumber(day: day.date, calendar: calendar, isSelected: calendar.isDate(day.date, inSameDayAs: date), font: .subheadline)
                    .frame(maxWidth: .infinity)
                    .frame(height: numberHeight, alignment: .center)
                Color.clear.frame(height: barsHeight)
                ForEach(timed.prefix(shown)) { event in
                    HStack(spacing: 3) {
                        Circle().fill(tint(event)).frame(width: 5, height: 5)
                        Text(title(event))
                            .font(.system(size: 10))
                            .lineLimit(1)
                        if event.isRecurring { RepeatBadge() }
                    }
                    .frame(height: laneHeight)
                    .padding(.leading, 4)
                }
                if hidden > 0 {
                    Text("+\(hidden) more")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(height: laneHeight)
                        .padding(.leading, 4)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .opacity(day.isInMonth ? 1 : 0.4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func move(by months: Int) {
        withAnimation(.snappy) {
            date = calendar.date(byAdding: .month, value: months, to: date) ?? date
        }
    }
}
