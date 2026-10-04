//
//  WeekView.swift
//  CalendarUI
//

import SwiftUI

/// Several days side by side, Calendar.app style: a header of days, all-day
/// bars across them, and a timeline column for each.
///
/// Seven days suits an iPad or a Mac; three suits a phone. With seven the
/// view shows the week containing `date`; with fewer it starts at `date`.
public struct WeekView<Event: CalendarEvent, Tile: View>: View {

    @Environment(\.calendarStyle) private var style
    @Binding private var date: Date
    private let events: [Event]
    private let calendar: Calendar
    private let hours: OpeningHours?
    private let dayCount: Int
    private let tile: (Event) -> Tile
    private let onSelect: ((Event) -> Void)?

    /// A multi-day view drawing each event with your own tile.
    public init(
        events: [Event], date: Binding<Date>, calendar: Calendar = .current, dayCount: Int = 7, hours: OpeningHours? = nil,
        onSelect: ((Event) -> Void)? = nil, @ViewBuilder tile: @escaping (Event) -> Tile
    ) {
        _date = date
        self.events = events
        self.calendar = calendar
        self.hours = hours
        self.dayCount = max(dayCount, 1)
        self.tile = tile
        self.onSelect = onSelect
    }

    private var days: [Date] {
        dayCount == 7
            ? Timetable.week(containing: date, calendar: calendar)
            : Timetable.days(from: date, count: dayCount, calendar: calendar)
    }

    public var body: some View {
        let days = days
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                StepButton(systemImage: "chevron.left") { move(by: -1) }
                Text(calendar.rangeTitle(days))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                StepButton(systemImage: "chevron.right") { move(by: 1) }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            HStack(spacing: 0) {
                Color.clear.frame(width: style.hourLabelWidth, height: 1)
                ForEach(days, id: \.self) { day in
                    Button { date = day } label: {
                        VStack(spacing: 2) {
                            Text(calendar.format(day) { $0.weekday(.abbreviated) })
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            DayNumber(day: day, calendar: calendar, isSelected: calendar.isDate(day, inSameDayAs: date))
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)
            Divider()
            AllDayLanes(days: days, events: events, calendar: calendar, tile: tile, onSelect: onSelect)
            Timeline(days: days, events: events, calendar: calendar, selectedDay: date, hours: hours, tile: tile, onSelect: onSelect)
        }
        .swipeToStep(move)
    }

    private func move(by pages: Int) {
        withAnimation(.snappy) {
            date = calendar.date(byAdding: .day, value: pages * dayCount, to: date) ?? date
        }
    }
}

extension WeekView where Tile == EventTile<EventTileLabel> {

    /// A multi-day view with the standard tile: a title in a colour.
    public init(
        events: [Event], date: Binding<Date>, calendar: Calendar = .current, dayCount: Int = 7, hours: OpeningHours? = nil,
        title: @escaping (Event) -> String, tint: @escaping (Event) -> Color = { _ in .accentColor },
        onSelect: ((Event) -> Void)? = nil
    ) {
        self.init(events: events, date: date, calendar: calendar, dayCount: dayCount, hours: hours, onSelect: onSelect) { event in
            EventTile(title(event), subtitle: event.isAllDay ? nil : calendar.timeRange(event.start, event.end), tint: tint(event), repeats: event.isRecurring)
        }
    }
}
