//
//  Progress.swift
//  CalendarCore
//
//  How far through the day someone is: the range of their day the moment
//  falls in, as a fraction, time gone and time left. Ranges may end past
//  midnight, so last night's range can still be running this morning.
//

import Foundation

extension Timetable {

    /// The range `now` falls in, and how far through it is; nil between ranges.
    ///
    /// Ranges are tried on today and — for those running past midnight — on
    /// yesterday, so a day of 08:00 to 02:00 is still in progress at 01:00.
    public static func progress(at now: Date, through ranges: [DayRange], calendar: Calendar = .current) -> RangeProgress? {
        Progress.find(now, calendar: calendar) { _ in ranges }
    }

    /// The same, with ranges that differ by weekday — a range belongs to the
    /// weekday it starts on, so Friday's late night ends on Saturday morning.
    public static func progress(at now: Date, through weekly: [Locale.Weekday: [DayRange]],
                                calendar: Calendar = .current) -> RangeProgress? {
        Progress.find(now, calendar: calendar) { weekly[$0.weekday] ?? [] }
    }

    /// The instants a range covers when it starts on a given day.
    public static func interval(of range: DayRange, on day: CalendarDay, calendar: Calendar = .current) -> DateInterval {
        Progress.interval(of: range, on: day, in: calendar.timeZone)
    }
}

enum Progress {

    static func find(_ now: Date, calendar: Calendar, ranges: (CalendarDay) -> [DayRange]) -> RangeProgress? {
        let today = CalendarDay(now, in: calendar)
        for day in [today, today.adding(days: -1)] {
            for (index, range) in ranges(day).enumerated() {
                let span = interval(of: range, on: day, in: calendar.timeZone)
                guard span.start <= now, now < span.end else { continue }
                let elapsed = now.timeIntervalSince(span.start)
                return RangeProgress(index: index, interval: span, fraction: span.duration > 0 ? elapsed / span.duration : 1,
                                     elapsed: elapsed, remaining: span.end.timeIntervalSince(now))
            }
        }
        return nil
    }

    static func interval(of range: DayRange, on day: CalendarDay, in zone: TimeZone) -> DateInterval {
        let start = OpeningTimes.instant(range.start, on: day, in: zone)
        let endDay = range.end > range.start ? day : day.adding(days: 1)
        let end = OpeningTimes.instant(range.end, on: endDay, in: zone)
        return DateInterval(start: start, end: max(end, start))
    }
}
