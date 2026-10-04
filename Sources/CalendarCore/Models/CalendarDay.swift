//
//  CalendarDay.swift
//  CalendarCore
//

import Foundation

/// A date with no time and no zone: 4 September 2026, wherever you are.
///
/// Check-in days, closures and seasons are days, not instants. Stored as an
/// instant, "the 4th" becomes the 3rd for anybody west of where it was saved;
/// stored as this, it stays the 4th. Always Gregorian. A ``Calendar`` passed
/// to ``init(_:in:)`` or ``date(in:)`` only decides the time zone, which is
/// what says which day an instant belongs to.
public struct CalendarDay: Sendable, Hashable, Codable, Comparable, CustomStringConvertible {

    /// The year.
    public let year: Int

    /// The month, 1 to 12.
    public let month: Int

    /// The day of the month, 1 to 31.
    public let day: Int

    /// A day, checked.
    ///
    /// - Throws: ``TimetableError/badDay(year:month:day:)`` for a day that
    ///   does not exist, such as 29 February in a common year.
    public init(year: Int, month: Int, day: Int) throws(TimetableError) {
        guard DayMath.isValid(year: year, month: month, day: day) else {
            throw .badDay(year: year, month: month, day: day)
        }
        self.init(unchecked: year, month, day)
    }

    /// The day an instant falls on, in a calendar's time zone.
    public init(_ date: Date, in calendar: Calendar = .current) {
        self = DayMath.day(of: date, in: calendar.timeZone)
    }

    init(unchecked year: Int, _ month: Int, _ day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The first instant of this day in a calendar's time zone.
    public func date(in calendar: Calendar = .current) -> Date {
        DayMath.start(of: self, in: calendar.timeZone)
    }

    /// The day `count` days later, or earlier when negative.
    public func adding(days count: Int) -> CalendarDay {
        DayMath.adding(count, to: self)
    }

    /// Whole days from this one to another; negative when `other` is earlier.
    public func days(until other: CalendarDay) -> Int {
        DayMath.distance(from: self, to: other)
    }

    /// The day of the week.
    public var weekday: Locale.Weekday {
        DayMath.weekday(of: self)
    }

    /// `2026-09-04`.
    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
