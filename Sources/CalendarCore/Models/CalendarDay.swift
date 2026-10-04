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
public struct CalendarDay: Sendable, Hashable, Codable {

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
}
