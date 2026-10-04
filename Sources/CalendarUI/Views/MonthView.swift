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
    @Environment(\.calendarEditor) private var editor
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
        let weekNumbers = style.weekNumbers.map { Timetable.weekNumbers(of: grid, numbering: $0, calendar: calendar) }
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
                if weekNumbers != nil { Color.clear.frame(width: weekNumberWidth, height: 1) }
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
                        HStack(alignment: .top, spacing: 0) {
                            if let weekNumbers { WeekNumber(weekNumbers[row]) }
                            TitledWeek(week, perDay: Array(perDay[(row * 7)..<(row * 7 + 7)]))
                        }
                    }
                }
            } else {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    ForEach(Array(grid.weeks.enumerated()), id: \.offset) { row, week in
                        Divider()
                        GridRow {
                            if let weekNumbers { WeekNumber(weekNumbers[row]) }
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
        .accessibilityLabel(Text(spokenDay(day.date, eventCount: events.count)))
        .accessibilityAddTraits(calendar.isDate(day.date, inSameDayAs: date) ? .isSelected : [])
    }

    // MARK: - Week numbers

    private var weekNumberWidth: CGFloat { 26 }

    private func WeekNumber(_ number: Int) -> some View {
        Text(number.formatted())
            .font(.caption2.weight(.medium).monospacedDigit())
            .foregroundStyle(.tertiary)
            .frame(width: weekNumberWidth)
            .padding(.top, 10)
            .accessibilityLabel(Text("Week \(number)", bundle: .module))
    }

    // MARK: - Titles style

    /// Whether an event is drawn as a bar rather than listed under its day.
    private func isBar(_ event: Event) -> Bool {
        event.isAllDay || !calendar.isDate(event.start, inSameDayAs: event.end.addingTimeInterval(-1))
    }

    @ScaledMetric(relativeTo: .caption2) private var laneHeight: CGFloat = 17
    @ScaledMetric(relativeTo: .subheadline) private var numberHeight: CGFloat = 36

    /// One week: day numbers, bars across the days, then each day's timed
    /// events. With editing on, bars and lines drag to other days — across
    /// columns and down into other weeks.
    private func TitledWeek(_ week: [GridDay], perDay: [[Event]]) -> some View {
        let days = week.map(\.date)
        let barLimit = max(style.monthPillLimit - 1, 1)
        let lanes = Timetable.lanes(events.filter(isBar), across: days, calendar: calendar, maximumLanes: barLimit)
        let barsHeight = CGFloat(lanes.laneCount) * laneHeight
        return GeometryReader { geometry in
            let column = geometry.size.width / 7
            let row = geometry.size.height + 1
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.element.id) { index, day in
                        TitledDay(day, timed: perDay[index].filter { !isBar($0) }, hiddenBars: lanes.hidden[index],
                                  barsHeight: barsHeight, lanesShown: lanes.laneCount, total: perDay[index].count,
                                  column: column, row: row)
                            .frame(width: column)
                    }
                }
                ForEach(lanes.bars) { bar in
                    Bar(bar)
                        .frame(width: max(column * CGFloat(bar.length) - 4, 0), height: laneHeight - 2)
                        .selectable(bar.event, calendar: calendar, onSelect: nil)
                        .modifier(MonthDrag(event: bar.event, column: column, row: row, calendar: calendar))
                        .padding(.leading, column * CGFloat(bar.firstDay) + 2)
                        .padding(.top, numberHeight + CGFloat(bar.lane) * laneHeight)
                }
            }
        }
        .frame(minHeight: numberHeight + CGFloat(style.monthPillLimit + 1) * laneHeight)
        .zIndex(perDay.joined().contains { editor?.isDragging($0.id) == true } ? 1 : 0)
    }

    private func Bar(_ bar: LaneBar<Event>) -> some View {
        let leading: CGFloat = bar.continuesBefore ? 0 : 4
        let trailing: CGFloat = bar.continuesAfter ? 0 : 4
        return HStack(spacing: 3) {
            Text(title(bar.event))
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
            if bar.event.isRecurring { RepeatBadge().foregroundStyle(.white.opacity(0.8)) }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(tint(bar.event), in: UnevenRoundedRectangle(
            topLeadingRadius: leading, bottomLeadingRadius: leading,
            bottomTrailingRadius: trailing, topTrailingRadius: trailing, style: .continuous))
    }

    private func TitledDay(_ day: GridDay, timed: [Event], hiddenBars: Int, barsHeight: CGFloat, lanesShown: Int, total: Int,
                           column: CGFloat, row: CGFloat) -> some View {
        let lines = max(style.monthPillLimit + 1 - lanesShown, 1)
        let overflow = timed.count + hiddenBars > lines
        let shown = overflow ? max(lines - 1, 0) : timed.count
        let hidden = timed.count - shown + hiddenBars
        let choose = {
            date = day.date
            editor?.select(nil, id: nil)
            editor?.pasteTarget = PasteTarget(date: day.date, isDay: true)
            onSelectDay?(day.date)
        }
        return VStack(alignment: .leading, spacing: 0) {
            Button(action: choose) {
                DayNumber(day: day.date, calendar: calendar, isSelected: calendar.isDate(day.date, inSameDayAs: date), font: .subheadline)
                    .frame(maxWidth: .infinity)
                    .frame(height: numberHeight, alignment: .center)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(spokenDay(day.date, eventCount: total)))
            .accessibilityAddTraits(calendar.isDate(day.date, inSameDayAs: date) ? .isSelected : [])
            Color.clear.frame(height: barsHeight)
            ForEach(timed.prefix(shown)) { event in
                HStack(spacing: 3) {
                    Circle().fill(tint(event)).frame(width: 5, height: 5)
                    Text(title(event))
                        .font(.caption2)
                        .lineLimit(1)
                    if event.isRecurring { RepeatBadge() }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: laneHeight)
                .padding(.horizontal, 4)
                .selectable(event, calendar: calendar, onSelect: nil)
                .modifier(MonthDrag(event: event, column: column, row: row, calendar: calendar))
            }
            if hidden > 0 {
                Text("+\(hidden) more", bundle: .module)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(height: laneHeight)
                    .padding(.leading, 4)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .opacity(day.isInMonth ? 1 : 0.4)
        .contentShape(Rectangle())
        .onTapGesture(perform: choose)
    }

    /// "Sunday 4 October, 3 events".
    private func spokenDay(_ day: Date, eventCount: Int) -> String {
        let name = calendar.format(day) { $0.weekday(.wide).day().month(.wide) }
        return eventCount == 0 ? name : name + ", " + String(localized: "\(eventCount) events", bundle: .module)
    }

    private func move(by months: Int) {
        withAnimation(.snappy) {
            date = calendar.date(byAdding: .month, value: months, to: date) ?? date
        }
    }
}
