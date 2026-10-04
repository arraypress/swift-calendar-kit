//
//  DayTime.swift
//  CalendarCore
//

import Foundation

/// A wall-clock time with no date: 09:30.
///
/// Runs from 00:00 to 24:00. 24:00 exists so a window can close at the end of
/// the day without pretending to close at 23:59.
public struct DayTime: Sendable, Hashable, Codable {

    /// The hour, 0 to 24.
    public let hour: Int

    /// The minute, 0 to 59; always 0 at 24:00.
    public let minute: Int

    /// A time, checked.
    ///
    /// - Throws: ``TimetableError/badTime(hour:minute:)`` outside 00:00 to 24:00.
    public init(hour: Int, minute: Int = 0) throws(TimetableError) {
        guard Clock.isValid(hour: hour, minute: minute) else { throw .badTime(hour: hour, minute: minute) }
        self.init(unchecked: hour, minute)
    }

    /// A time read from `HH:mm` (or `H:mm`).
    ///
    /// - Throws: ``TimetableError/unreadableTime(_:)`` for anything else.
    public init(_ text: String) throws(TimetableError) {
        self = try Clock.parse(text)
    }

    init(unchecked hour: Int, _ minute: Int) {
        self.hour = hour
        self.minute = minute
    }
}
