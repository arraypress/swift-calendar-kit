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
        self.init(weekly: Dictionary(uniqueKeysWithValues: days.map { ($0, windows) }))
    }

    /// The windows on one day, earliest first, with any exception applied.
    public func windows(on day: CalendarDay) -> [TimeWindow] {
        (exceptions[day] ?? weekly[day.weekday] ?? []).sorted { $0.opens < $1.opens }
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
