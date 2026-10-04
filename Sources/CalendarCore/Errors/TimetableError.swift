//
//  TimetableError.swift
//  CalendarCore
//

import Foundation

/// A value that cannot describe a real day or time.
public enum TimetableError: Error, Sendable, Hashable, CustomStringConvertible {

    /// A day that does not exist, such as 30 February.
    case badDay(year: Int, month: Int, day: Int)

    /// A time outside 00:00 to 24:00.
    case badTime(hour: Int, minute: Int)

    /// Text that is not `HH:mm`.
    case unreadableTime(String)

    /// A window that closes at or before it opens.
    case badWindow(opens: DayTime, closes: DayTime)

    public var description: String {
        switch self {
        case let .badDay(year, month, day):
            return "\(year)-\(month)-\(day) is not a day in the Gregorian calendar"
        case let .badTime(hour, minute):
            return "\(hour):\(minute) is not a time of day; use 00:00 to 24:00"
        case let .unreadableTime(text):
            return "\"\(text)\" is not a time; use HH:mm, such as 09:30"
        case let .badWindow(opens, closes):
            return "a window from \(opens) to \(closes) closes before it opens; split a window across midnight into two days"
        }
    }
}
