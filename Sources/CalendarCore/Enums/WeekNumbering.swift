//
//  WeekNumbering.swift
//  CalendarCore
//

import Foundation

/// How weeks are numbered down the side of a month.
public enum WeekNumbering: Sendable, Hashable {

    /// The calendar's own rule — its first weekday and how many days the first
    /// week of the year needs, as the user's region sets them. What
    /// Calendar.app shows.
    case regional

    /// ISO 8601: weeks start on Monday and week 1 holds the year's first
    /// Thursday, so 1 January 2027 is in week 53 of 2026. A row that starts on
    /// Sunday is numbered by the ISO week its Monday falls in.
    case iso8601
}
