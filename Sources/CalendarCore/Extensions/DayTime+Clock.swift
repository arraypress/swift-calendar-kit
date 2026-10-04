//
//  DayTime+Clock.swift
//  CalendarCore
//

import Foundation

extension DayTime {

    /// Midnight at the start of the day.
    public static let startOfDay = DayTime(unchecked: 0, 0)

    /// Midnight at the end of the day.
    public static let endOfDay = DayTime(unchecked: 24, 0)

    /// Minutes since the start of the day.
    public var minutesIntoDay: Int { hour * 60 + minute }
}

extension DayTime: Comparable {

    public static func < (lhs: DayTime, rhs: DayTime) -> Bool {
        lhs.minutesIntoDay < rhs.minutesIntoDay
    }
}

extension DayTime: CustomStringConvertible {

    /// `09:30`.
    public var description: String { Clock.text(self) }
}
