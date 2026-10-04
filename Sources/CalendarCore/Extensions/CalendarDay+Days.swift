//
//  CalendarDay+Days.swift
//  CalendarCore
//

import Foundation

extension CalendarDay {

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
}

extension CalendarDay: Comparable {

    public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        DayMath.precedes(lhs, rhs)
    }
}

extension CalendarDay: CustomStringConvertible {

    /// `2026-09-04`.
    public var description: String { DayMath.text(self) }
}
