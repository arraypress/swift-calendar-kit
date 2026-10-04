//
//  Listings.swift
//  CalendarCore
//
//  Events as a day-by-day list, and bookings as rows on a board.
//

import Foundation

extension Timetable {

    /// Events day by day, for a list view. Each event appears on every day it
    /// touches, cut to that day. Days with nothing on are left out unless
    /// `includeEmptyDays` is set.
    public static func agenda<E: CalendarEvent>(_ events: [E], on days: [Date], calendar: Calendar = .current,
                                                includeEmptyDays: Bool = false) -> [AgendaDay<E>] {
        Listings.agenda(events, days: days, in: calendar, includeEmptyDays: includeEmptyDays)
    }

    /// Bookings as rows on a board: one row per resource, in the order given,
    /// each with its bookings in lanes across the days, its free days, and
    /// the days it is double-booked.
    ///
    /// - Parameter resourceOf: which resource a booking belongs to. Bookings
    ///   for a resource not in `resources` are left off the board.
    public static func board<R: Hashable, E: CalendarEvent>(
        _ events: [E], resources: [R], resourceOf: (E) -> R, across days: [Date], calendar: Calendar = .current
    ) -> [BoardRow<R, E>] {
        Listings.board(events, resources: resources, resourceOf: resourceOf, days: days, in: calendar)
    }
}

enum Listings {

    static func occupancy(_ isFree: [Bool]) -> Double {
        isFree.isEmpty ? 0 : Double(isFree.filter { !$0 }.count) / Double(isFree.count)
    }

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
