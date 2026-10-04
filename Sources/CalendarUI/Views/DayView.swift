//
//  DayView.swift
//  CalendarUI
//

import SwiftUI

/// One day: a week strip to move between days, the all-day bars, and the
/// timeline with overlapping events side by side.
public struct DayView<Event: CalendarEvent, Tile: View>: View {

    @Binding private var date: Date
    private let events: [Event]
    private let calendar: Calendar
    private let hours: OpeningHours?
    private let secondTimeZone: TimeZone?
    private let tile: (Event) -> Tile
    private let marker: (Date) -> Color?
    private let onSelect: ((Event) -> Void)?

    /// A day view drawing each event with your own tile.
    ///
    /// - Parameters:
    ///   - hours: opening or working hours; the closed stretches are shaded.
    ///   - secondTimeZone: a second column of hour labels in another zone.
    ///   - marker: the dot colour under a day in the week strip; by default
    ///     the accent colour on days with events.
    public init(
        events: [Event], date: Binding<Date>, calendar: Calendar = .current, hours: OpeningHours? = nil,
        secondTimeZone: TimeZone? = nil,
        marker: ((Date) -> Color?)? = nil, onSelect: ((Event) -> Void)? = nil,
        @ViewBuilder tile: @escaping (Event) -> Tile
    ) {
        _date = date
        self.events = events
        self.calendar = calendar
        self.hours = hours
        self.secondTimeZone = secondTimeZone
        self.tile = tile
        self.onSelect = onSelect
        self.marker = marker ?? Self.defaultMarker(events, calendar)
    }

    public var body: some View {
        VStack(spacing: 0) {
            WeekStrip(selection: $date, calendar: calendar, marker: marker)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            Text(calendar.format(date) { $0.weekday(.wide).day().month(.wide).year() })
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 6)
            Divider()
            AllDayLanes(days: [calendar.startOfDay(for: date)], events: events, calendar: calendar, tile: tile, onSelect: onSelect)
            Timeline(days: [calendar.startOfDay(for: date)], events: events, calendar: calendar, hours: hours, secondZone: secondTimeZone, tile: tile, onSelect: onSelect)
        }
    }

    static func defaultMarker(_ events: [Event], _ calendar: Calendar) -> (Date) -> Color? {
        { day in
            let interval = calendar.dateInterval(of: .day, for: day)!
            return Timetable.events(events, on: [interval.start], calendar: calendar)[0].isEmpty ? nil : .accentColor
        }
    }
}

extension DayView where Tile == EventTile<EventTileLabel> {

    /// A day view with the standard tile: a title in a colour.
    public init(
        events: [Event], date: Binding<Date>, calendar: Calendar = .current, hours: OpeningHours? = nil,
        secondTimeZone: TimeZone? = nil,
        title: @escaping (Event) -> String, tint: @escaping (Event) -> Color = { _ in .accentColor },
        onSelect: ((Event) -> Void)? = nil
    ) {
        self.init(events: events, date: date, calendar: calendar, hours: hours, secondTimeZone: secondTimeZone, onSelect: onSelect) { event in
            EventTile(title(event), subtitle: event.isAllDay ? nil : calendar.timeRange(event.start, event.end), tint: tint(event), repeats: event.isRecurring)
        }
    }
}
