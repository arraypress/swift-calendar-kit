//
//  Formatting.swift
//  CalendarUI
//
//  Dates written in the calendar's own locale and zone, not the device's —
//  a view handed a Tokyo calendar labels Tokyo days.
//

import Foundation

extension Calendar {

    func format(_ date: Date, _ style: (Date.FormatStyle) -> Date.FormatStyle) -> String {
        let base = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale ?? .current, calendar: self, timeZone: timeZone)
        return date.formatted(style(base))
    }

    func monthTitle(_ date: Date) -> String { format(date) { $0.month(.wide).year() } }

    /// `September 2026`, or `Sep – Oct 2026` for days spanning two months.
    func rangeTitle(_ days: [Date]) -> String {
        guard let first = days.first, let last = days.last, !isDate(first, equalTo: last, toGranularity: .month) else {
            return monthTitle(days.first ?? .now)
        }
        let sameYear = isDate(first, equalTo: last, toGranularity: .year)
        let start = format(first) { sameYear ? $0.month(.abbreviated) : $0.month(.abbreviated).year() }
        return "\(start) – \(format(last) { $0.month(.abbreviated).year() })"
    }

    /// `09:00–10:30` in the locale's clock.
    func timeRange(_ start: Date, _ end: Date) -> String {
        let time = { (date: Date) in self.format(date) { $0.hour().minute() } }
        return end > start ? "\(time(start))–\(time(end))" : time(start)
    }

    func monthName(_ date: Date) -> String { format(date) { $0.month(.abbreviated) } }

    func dayNumber(_ date: Date) -> String { format(date) { $0.day() } }

    func hourLabel(_ date: Date) -> String { format(date) { $0.hour(.defaultDigits(amPM: .abbreviated)) } }

    func yearTitle(_ date: Date) -> String { format(date) { $0.year() } }

    func dayTitle(_ date: Date) -> String { format(date) { $0.weekday(.abbreviated).day().month(.abbreviated) } }

    func isToday(_ date: Date) -> Bool { isDate(date, inSameDayAs: .now) }
}
