//
//  Timetable.swift
//  CalendarCore
//
//  The namespace. Every call takes the calendar it works in, because the
//  answer depends on it: a US calendar's week starts on Sunday, a UK one's on
//  Monday, and "which day is this" depends on the zone.
//

import Foundation

/// The arithmetic behind calendar screens and booking flows.
///
/// Three jobs, all pure functions of their arguments:
///
/// - **Drawing calendars** — month, week and year grids; where timed events
///   sit on a day's timeline, overlaps side by side; multi-day bars in lanes.
/// - **Booking appointments** — opening hours, free time, bookable slots,
///   clashes, and which of several resources is free.
/// - **Booking stays** — nights, house rules, which days a date picker should
///   offer, and seasonal prices.
///
/// Nothing here reads the clock, so nothing changes answer at midnight.
public enum Timetable {}
