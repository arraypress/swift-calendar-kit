//
//  OpeningHours.swift
//  CalendarCore
//

import Foundation

/// When somewhere is open: a weekly pattern, and the days that differ from it.
///
/// A day can have several windows (09:00–12:30 and 13:30–17:00 is a lunch
/// break). A day with no windows is closed. An exception replaces the weekly
/// pattern for its day entirely, so a bank holiday is `[]` and a late opening
/// before Christmas is its own list.
public struct OpeningHours: Sendable, Hashable, Codable {

    /// The usual windows for each day of the week; a missing day is closed.
    public var weekly: [Locale.Weekday: [TimeWindow]]

    /// Days that differ from the weekly pattern; `[]` is closed.
    public var exceptions: [CalendarDay: [TimeWindow]]

    /// Opening hours from a weekly pattern and its exceptions.
    public init(weekly: [Locale.Weekday: [TimeWindow]] = [:], exceptions: [CalendarDay: [TimeWindow]] = [:]) {
        self.weekly = weekly
        self.exceptions = exceptions
    }

    /// The same windows on each of the days named.
    public init(_ windows: [TimeWindow], on days: Set<Locale.Weekday>) {
        self.init(weekly: OpeningTimes.weekly(windows, on: days))
    }
}
