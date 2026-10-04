//
//  TimeWindow.swift
//  CalendarCore
//

import Foundation

/// One stretch of a day, such as 09:00 to 12:30.
///
/// Never crosses midnight. A bar open 20:00 to 02:00 is two windows on two
/// days, because the 02:00 half belongs to the next day's closures and the
/// next day's weekday.
public struct TimeWindow: Sendable, Hashable, Codable {

    /// When it opens.
    public let opens: DayTime

    /// When it closes, exclusive.
    public let closes: DayTime

    /// A window, checked.
    ///
    /// - Throws: ``TimetableError/badWindow(opens:closes:)`` when it closes at
    ///   or before it opens.
    public init(opens: DayTime, closes: DayTime) throws(TimetableError) {
        guard closes > opens else { throw .badWindow(opens: opens, closes: closes) }
        self.opens = opens
        self.closes = closes
    }

    /// A window read from two `HH:mm` times: `TimeWindow("09:00", "17:30")`.
    public init(_ opens: String, _ closes: String) throws(TimetableError) {
        try self.init(opens: try DayTime(opens), closes: try DayTime(closes))
    }
}
