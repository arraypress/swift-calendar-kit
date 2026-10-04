//
//  DayRange.swift
//  CalendarCore
//

import Foundation

/// A stretch of someone's day by the clock, which may run past midnight:
/// 08:00 to 02:00 is a day that ends at two the next morning.
///
/// Unlike ``TimeWindow`` — opening hours, which a closure or a weekday must be
/// able to cut — a range that ends at or before it starts simply ends the next
/// day. That is what "my day ends at 2am" means.
public struct DayRange: Sendable, Hashable, Codable {

    /// When it starts.
    public let start: DayTime

    /// When it ends; at or before `start` means the following day.
    public let end: DayTime

    /// A range.
    public init(start: DayTime, end: DayTime) {
        self.start = start
        self.end = end
    }

    /// A range read from two `HH:mm` times: `DayRange("08:00", "02:00")`.
    public init(_ start: String, _ end: String) throws(TimetableError) {
        self.init(start: try DayTime(start), end: try DayTime(end))
    }
}

/// Where the moment sits in a ``DayRange`` — the figures a day-progress bar draws.
public struct RangeProgress: Sendable, Hashable {

    /// Which of the ranges given it is, by position.
    public let index: Int

    /// The range as instants: today's, or yesterday's still running past midnight.
    public let interval: DateInterval

    /// How much has passed, 0 to 1.
    public let fraction: Double

    /// Time gone.
    public let elapsed: TimeInterval

    /// Time left.
    public let remaining: TimeInterval
}
