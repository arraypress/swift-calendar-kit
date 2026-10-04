//
//  EventDays.swift
//  CalendarCore
//
//  Which days an event touches. The one rule everything else leans on.
//

import Foundation

enum EventDays {

    /// The stretch of time an event covers. An all-day event whose end is
    /// not after its start covers its start's whole day; a timed one is an
    /// instant.
    static func coverage<E: CalendarEvent>(of event: E, in calendar: Calendar) -> (start: Date, end: Date) {
        if event.end > event.start { return (event.start, event.end) }
        if event.isAllDay { return (event.start, calendar.dateInterval(of: .day, for: event.start)!.end) }
        return (event.start, event.start)
    }

    /// Whether an event touches a stretch of time. An instant touches the
    /// stretch it falls in, counting the start and not the end.
    static func touches<E: CalendarEvent>(_ event: E, _ interval: DateInterval, in calendar: Calendar) -> Bool {
        let (start, end) = coverage(of: event, in: calendar)
        if end == start { return start >= interval.start && start < interval.end }
        return start < interval.end && end > interval.start
    }

    static func day(_ date: Date, in calendar: Calendar) -> DateInterval {
        calendar.dateInterval(of: .day, for: date)!
    }

    /// The events touching each day, all-day first, then by start, then the
    /// longer first.
    static func byDay<E: CalendarEvent>(_ events: [E], days: [Date], in calendar: Calendar) -> [[E]] {
        days.map { date in
            let day = day(date, in: calendar)
            return ordered(events.filter { touches($0, day, in: calendar) })
        }
    }

    static func ordered<E: CalendarEvent>(_ events: [E]) -> [E] {
        events.enumerated().sorted { a, b in
            if a.element.isAllDay != b.element.isAllDay { return a.element.isAllDay }
            if a.element.start != b.element.start { return a.element.start < b.element.start }
            if a.element.end != b.element.end { return a.element.end > b.element.end }
            return a.offset < b.offset
        }.map(\.element)
    }

    /// The hour lines of a day, walked in real time so they line up with
    /// events placed by ``Placement``: 23 lines in the spring, 25 in autumn.
    static func hourMarks(on date: Date, every hours: Int, in calendar: Calendar) -> [HourMark] {
        let day = day(date, in: calendar)
        let step = TimeInterval(max(hours, 1) * 3600)
        return stride(from: day.start, to: day.end, by: step).map { instant in
            HourMark(date: instant, hour: calendar.component(.hour, from: instant),
                     position: instant.timeIntervalSince(day.start) / day.duration)
        }
    }
}
