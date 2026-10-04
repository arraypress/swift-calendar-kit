//
//  OpeningHours+Days.swift
//  CalendarCore
//

import Foundation

extension OpeningHours {

    /// The windows on one day, earliest first, with any exception applied.
    public func windows(on day: CalendarDay) -> [TimeWindow] {
        OpeningTimes.windows(self, on: day)
    }

    /// Whether the place opens at all on a day.
    public func isOpen(on day: CalendarDay) -> Bool {
        !windows(on: day).isEmpty
    }

    /// Monday to Friday.
    public static let weekdays: Set<Locale.Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]

    /// Every day of the week.
    public static let everyDay: Set<Locale.Weekday> = Set(DayMath.weekdays)
}
