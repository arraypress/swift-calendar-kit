//
//  Listings.swift
//  CalendarCore
//
//  Events as a day-by-day list, and bookings as rows on a board.
//

import Foundation

enum Listings {

    static func agenda<E: CalendarEvent>(_ events: [E], days: [Date], in calendar: Calendar, includeEmptyDays: Bool) -> [AgendaDay<E>] {
        days.compactMap { date -> AgendaDay<E>? in
            let day = EventDays.day(date, in: calendar)
            let entries = EventDays.ordered(events.filter { EventDays.touches($0, day, in: calendar) }).map { event in
                let (start, end) = EventDays.coverage(of: event, in: calendar)
                let clippedStart = max(start, day.start)
                let clippedEnd = max(min(end, day.end), clippedStart)
                let (dayOfEvent, dayCount) = position(of: day.start, from: start, to: end, in: calendar)
                return AgendaEntry(
                    event: event, start: clippedStart, end: clippedEnd,
                    continuesFromPreviousDay: start < day.start, continuesToNextDay: end > day.end,
                    isAllDay: event.isAllDay || (clippedStart == day.start && clippedEnd == day.end),
                    dayOfEvent: dayOfEvent, eventDayCount: dayCount
                )
            }
            return entries.isEmpty && !includeEmptyDays ? nil : AgendaDay(day: day, entries: entries)
        }
    }

    /// Which day of an event a day is, and how many days it touches. An end
    /// at midnight belongs to the day before it: it does not touch the next.
    static func position(of day: Date, from start: Date, to end: Date, in calendar: Calendar) -> (Int, Int) {
        let first = calendar.startOfDay(for: start)
        let last = end > start ? calendar.startOfDay(for: end.addingTimeInterval(-1)) : first
        let count = { (from: Date, to: Date) in (calendar.dateComponents([.day], from: from, to: to).day ?? 0) + 1 }
        return (count(first, day), count(first, last))
    }

    static func board<R: Hashable, E: CalendarEvent>(
        _ events: [E], resources: [R], resourceOf: (E) -> R, days: [Date], in calendar: Calendar
    ) -> [BoardRow<R, E>] {
        let grouped = Dictionary(grouping: events, by: resourceOf)
        return resources.map { resource in
            let lanes = Placement.lanes(grouped[resource] ?? [], across: days, in: calendar, maximumLanes: nil)
            var booked = Array(repeating: 0, count: days.count)
            for bar in lanes.bars {
                for day in bar.firstDay...bar.lastDay { booked[day] += 1 }
            }
            return BoardRow(resource: resource, lanes: lanes, isFree: booked.map { $0 == 0 },
                            clashingDays: booked.indices.filter { booked[$0] > 1 })
        }
    }
}
