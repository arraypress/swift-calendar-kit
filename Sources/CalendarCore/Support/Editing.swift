//
//  Editing.swift
//  CalendarCore
//
//  What a drag means in time: whole days across, snapped minutes down, and
//  the series edits a calendar app offers when one occurrence of a repeating
//  event is moved or deleted.
//

import Foundation

enum Edits {

    /// Seconds since the day's first instant, snapped to the nearest multiple
    /// of `snap`, and turned back into an instant on that day.
    static func snapped(_ date: Date, to snap: TimeInterval, in calendar: Calendar) -> Date {
        guard snap > 0 else { return date }
        let day = calendar.startOfDay(for: date)
        let seconds = date.timeIntervalSince(day)
        return day.addingTimeInterval((seconds / snap).rounded() * snap)
    }

    static func moved(_ interval: DateInterval, days: Int, by offset: TimeInterval, snap: TimeInterval, in calendar: Calendar) -> DateInterval {
        let shifted = calendar.date(byAdding: .day, value: days, to: interval.start) ?? interval.start
        let start = snapped(shifted.addingTimeInterval(offset), to: snap, in: calendar)
        return DateInterval(start: start, duration: interval.duration)
    }

    static func movedDays(_ interval: DateInterval, by days: Int, in calendar: Calendar) -> DateInterval {
        let start = calendar.date(byAdding: .day, value: days, to: interval.start) ?? interval.start
        let end = calendar.date(byAdding: .day, value: days, to: interval.end) ?? interval.end
        return DateInterval(start: start, end: max(end, start))
    }

    static func resized(_ interval: DateInterval, end proposed: Date, snap: TimeInterval, minimum: TimeInterval, in calendar: Calendar) -> DateInterval {
        let end = snapped(proposed, to: snap, in: calendar)
        return DateInterval(start: interval.start, end: max(end, interval.start.addingTimeInterval(max(minimum, snap, 1))))
    }

    /// A rule with a new count, end and exceptions, every other part kept.
    /// ChronoKit's rules are values with every part fixed at creation, so an
    /// edit is a rebuild.
    static func rule(_ rule: RecurrenceRule, count: Int?, until: Date?, exceptions: Set<Date>) -> RecurrenceRule {
        (try? RecurrenceRule(
            frequency: rule.frequency, interval: rule.interval, byDay: rule.byDay, byMonthDay: rule.byMonthDay, byMonth: rule.byMonth,
            bySetPos: rule.bySetPos, count: count, until: until, weekStart: rule.weekStart,
            businessDayOrdinal: rule.businessDayOrdinal, exceptions: exceptions, additions: rule.additions
        )) ?? rule
    }

    static func span(from a: Date, to b: Date, snap: TimeInterval, in calendar: Calendar) -> DateInterval {
        let start = snapped(min(a, b), to: snap, in: calendar)
        let end = snapped(max(a, b), to: snap, in: calendar)
        return DateInterval(start: start, end: max(end, start.addingTimeInterval(max(snap, 1))))
    }
}

extension Timetable {

    /// An interval moved by whole days and then by an offset, its start
    /// snapped to the nearest `snap` seconds into its day, its length kept.
    ///
    /// Days are calendar days, so a 09:00 meeting dragged across the clock
    /// change is still at 09:00. This is what a drag across a week view
    /// means: columns across, minutes down.
    public static func moved(_ interval: DateInterval, days: Int = 0, by offset: TimeInterval = 0,
                             snap: TimeInterval = 15 * 60, calendar: Calendar = .current) -> DateInterval {
        Edits.moved(interval, days: days, by: offset, snap: snap, in: calendar)
    }

    /// An all-day or nightly interval moved by whole calendar days at both ends.
    public static func moved(_ interval: DateInterval, byDays days: Int, calendar: Calendar = .current) -> DateInterval {
        Edits.movedDays(interval, by: days, in: calendar)
    }

    /// An interval with a new end, snapped, never shorter than `minimum` or one snap.
    public static func resized(_ interval: DateInterval, end: Date, snap: TimeInterval = 15 * 60,
                               minimum: TimeInterval = 0, calendar: Calendar = .current) -> DateInterval {
        Edits.resized(interval, end: end, snap: snap, minimum: minimum, in: calendar)
    }

    /// The interval a drag across empty time sweeps out, in either direction,
    /// both ends snapped, at least one snap long.
    public static func span(from start: Date, to end: Date, snap: TimeInterval = 15 * 60,
                            calendar: Calendar = .current) -> DateInterval {
        Edits.span(from: start, to: end, snap: snap, in: calendar)
    }
}
