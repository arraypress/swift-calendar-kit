//
//  HoursLine.swift
//  CalendarCore
//

import Foundation

/// One line of a week-at-a-glance: `Mon–Fri  9:00 AM – 5:00 PM`.
public struct HoursLine: Sendable, Hashable, Identifiable {

    /// The days the line covers, in the week's order.
    public let days: [Locale.Weekday]

    /// Their shared windows; empty when closed.
    public let windows: [TimeWindow]

    /// The days, in the calendar's language: `Mon`, `Sat, Sun`, `Mon–Fri`.
    public let dayLabel: String

    /// The hours, in the locale's clock: `09:00–17:00`, `9:00 AM – 5:00 PM`,
    /// two windows joined with a comma, or the closed label.
    public let hoursLabel: String

    /// Whether the days are closed.
    public var isClosed: Bool { windows.isEmpty }

    /// Identified by its first day.
    public var id: Locale.Weekday { days[0] }
}
