//
//  DayMath.swift
//  CalendarCore
//
//  CalendarDay arithmetic, done in UTC so no day is ever 23 or 25 hours long.
//

import Foundation

enum DayMath {

    /// Gregorian in UTC: every day is 86,400 seconds, so counting days is
    /// counting days.
    static let utc: Calendar = gregorian(in: TimeZone(identifier: "UTC")!)

    /// Foundation's weekday numbers, Sunday first, as `Locale.Weekday`.
    static let weekdays: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]

    static func gregorian(in zone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }

    static func isValid(year: Int, month: Int, day: Int) -> Bool {
        guard (1...12).contains(month), day >= 1,
              let date = utc.date(from: DateComponents(year: year, month: month, day: day)) else { return false }
        let parts = utc.dateComponents([.year, .month, .day], from: date)
        return parts.year == year && parts.month == month && parts.day == day
    }

    static func day(of date: Date, in zone: TimeZone) -> CalendarDay {
        let parts = gregorian(in: zone).dateComponents([.year, .month, .day], from: date)
        return CalendarDay(unchecked: parts.year!, parts.month!, parts.day!)
    }

    static func start(of day: CalendarDay, in zone: TimeZone) -> Date {
        let calendar = gregorian(in: zone)
        let noon = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12))!
        return calendar.startOfDay(for: noon)
    }

    static func adding(_ count: Int, to day: CalendarDay) -> CalendarDay {
        let date = utc.date(byAdding: .day, value: count, to: start(of: day, in: utc.timeZone))!
        return self.day(of: date, in: utc.timeZone)
    }

    static func distance(from a: CalendarDay, to b: CalendarDay) -> Int {
        utc.dateComponents([.day], from: start(of: a, in: utc.timeZone), to: start(of: b, in: utc.timeZone)).day!
    }

    static func precedes(_ a: CalendarDay, _ b: CalendarDay) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }

    static func text(_ day: CalendarDay) -> String {
        String(format: "%04d-%02d-%02d", day.year, day.month, day.day)
    }

    static func weekday(of day: CalendarDay) -> Locale.Weekday {
        weekdays[utc.component(.weekday, from: start(of: day, in: utc.timeZone)) - 1]
    }

    /// The `Locale.Weekday` for a Foundation weekday number, 1 (Sunday) to 7.
    static func weekday(foundation number: Int) -> Locale.Weekday {
        weekdays[number - 1]
    }

    /// The Foundation weekday number, 1 (Sunday) to 7, for a `Locale.Weekday`.
    static func foundationNumber(of weekday: Locale.Weekday) -> Int {
        weekdays.firstIndex(of: weekday)! + 1
    }
}
