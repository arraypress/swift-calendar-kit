//
//  MonthGrid.swift
//  CalendarCore
//

import Foundation

/// The boxes of a month view: whole weeks, starting on the calendar's first
/// weekday, with the neighbouring months' days filling the ends.
public struct MonthGrid: Sendable, Hashable, Identifiable {

    /// The month, from its first instant to the first instant of the next.
    public let month: DateInterval

    /// Rows of seven days.
    public let weeks: [[GridDay]]

    /// Identified by the month's first instant.
    public var id: Date { month.start }

    /// Every box, row by row.
    public var days: [GridDay] { weeks.flatMap { $0 } }
}

/// One box in a ``MonthGrid``.
public struct GridDay: Sendable, Hashable, Identifiable {

    /// The first instant of the day.
    public let date: Date

    /// The day of the month, as the calendar numbers it.
    public let number: Int

    /// Whether the day belongs to the grid's month rather than a neighbour.
    public let isInMonth: Bool

    /// Identified by the day's first instant.
    public var id: Date { date }
}
