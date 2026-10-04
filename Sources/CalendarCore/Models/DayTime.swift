//
//  DayTime.swift
//  CalendarCore
//

import Foundation

/// A wall-clock time with no date: 09:30.
///
/// Runs from 00:00 to 24:00. 24:00 exists so a window can close at the end of
/// the day without pretending to close at 23:59.
public struct DayTime: Sendable, Hashable, Codable, Comparable, CustomStringConvertible {

    /// The hour, 0 to 24.
    public let hour: Int

    /// The minute, 0 to 59; always 0 at 24:00.
    public let minute: Int

    /// Midnight at the start of the day.
    public static let startOfDay = DayTime(unchecked: 0, 0)

    /// Midnight at the end of the day.
    public static let endOfDay = DayTime(unchecked: 24, 0)

    /// A time, checked.
    ///
    /// - Throws: ``TimetableError/badTime(hour:minute:)`` outside 00:00 to 24:00.
    public init(hour: Int, minute: Int = 0) throws(TimetableError) {
        guard (0...23).contains(hour) && (0...59).contains(minute) || hour == 24 && minute == 0 else {
            throw .badTime(hour: hour, minute: minute)
        }
        self.init(unchecked: hour, minute)
    }

    /// A time read from `HH:mm` (or `H:mm`).
    ///
    /// - Throws: ``TimetableError/unreadableTime(_:)`` for anything else.
    public init(_ text: String) throws(TimetableError) {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[1].count == 2, (1...2).contains(parts[0].count),
              let hour = Int(parts[0]), let minute = Int(parts[1]) else {
            throw .unreadableTime(text)
        }
        try self.init(hour: hour, minute: minute)
    }

    init(unchecked hour: Int, _ minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    /// Minutes since the start of the day.
    public var minutesIntoDay: Int { hour * 60 + minute }

    /// `09:30`.
    public var description: String { String(format: "%02d:%02d", hour, minute) }

    public static func < (lhs: DayTime, rhs: DayTime) -> Bool {
        lhs.minutesIntoDay < rhs.minutesIntoDay
    }
}
