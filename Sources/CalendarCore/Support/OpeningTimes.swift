//
//  OpeningTimes.swift
//  CalendarCore
//
//  Opening hours turned into real instants, day by day, in a time zone.
//

import Foundation

extension Timetable {

    /// The open stretches from one day to another, inclusive, as instants in
    /// the calendar's time zone.
    public static func openIntervals(_ hours: OpeningHours, from first: CalendarDay, through last: CalendarDay,
                                     calendar: Calendar = .current) -> [DateInterval] {
        OpeningTimes.intervals(hours, from: first, through: last, in: calendar.timeZone)
    }
}

enum OpeningTimes {

    static func weekly(_ windows: [TimeWindow], on days: Set<Locale.Weekday>) -> [Locale.Weekday: [TimeWindow]] {
        Dictionary(uniqueKeysWithValues: days.map { ($0, windows) })
    }

    /// A day's windows: its exception if it has one, otherwise its weekday's.
    static func windows(_ hours: OpeningHours, on day: CalendarDay) -> [TimeWindow] {
        (hours.exceptions[day] ?? hours.weekly[day.weekday] ?? []).sorted { $0.opens < $1.opens }
    }

    /// Every open interval from `first` to `last` inclusive, in order.
    static func intervals(_ hours: OpeningHours, from first: CalendarDay, through last: CalendarDay, in zone: TimeZone) -> [DateInterval] {
        guard first <= last else { return [] }
        return (0...first.days(until: last)).flatMap { offset -> [DateInterval] in
            let day = first.adding(days: offset)
            return hours.windows(on: day).compactMap { interval(of: $0, on: day, in: zone) }
        }
    }

    /// A window on a particular day. `nil` only when a clock change swallows
    /// it whole (a window that opens and closes inside the skipped hour).
    static func interval(of window: TimeWindow, on day: CalendarDay, in zone: TimeZone) -> DateInterval? {
        let start = instant(window.opens, on: day, in: zone)
        let end = instant(window.closes, on: day, in: zone)
        return end > start ? DateInterval(start: start, end: end) : nil
    }

    /// A wall-clock time on a day. 24:00 is the start of the next day; a time
    /// inside a skipped hour lands on the first instant after the gap.
    static func instant(_ time: DayTime, on day: CalendarDay, in zone: TimeZone) -> Date {
        if time == .endOfDay { return day.adding(days: 1).date(in: DayMath.gregorian(in: zone)) }
        let calendar = DayMath.gregorian(in: zone)
        let parts = DateComponents(hour: time.hour, minute: time.minute, second: 0)
        let midnight = DayMath.start(of: day, in: zone)
        if time == .startOfDay { return midnight }
        return calendar.nextDate(after: midnight, matching: parts, matchingPolicy: .nextTime)!
    }
}
