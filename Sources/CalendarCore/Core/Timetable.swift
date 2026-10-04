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
public enum Timetable {

    // MARK: - Grids

    /// The month containing a date, as rows of whole weeks.
    public static func month(containing date: Date, calendar: Calendar = .current, rows: GridRows = .fitted) -> MonthGrid {
        Grids.month(containing: date, in: calendar, rows: rows)
    }

    /// Every month of the year containing a date.
    public static func year(containing date: Date, calendar: Calendar = .current, rows: GridRows = .fitted) -> [MonthGrid] {
        Grids.year(containing: date, in: calendar, rows: rows)
    }

    /// The seven days of the week containing a date, from the calendar's first weekday.
    public static func week(containing date: Date, calendar: Calendar = .current) -> [Date] {
        Grids.week(containing: date, in: calendar)
    }

    /// `count` consecutive days from a date's day — a three-day view, say.
    public static func days(from date: Date, count: Int, calendar: Calendar = .current) -> [Date] {
        Grids.days(from: date, count: count, in: calendar)
    }

    /// Weekday names in the order the calendar's week runs, in its locale.
    public static func weekdaySymbols(calendar: Calendar = .current, style: WeekdayStyle = .short) -> [String] {
        Grids.weekdaySymbols(in: calendar, style: style)
    }

    // MARK: - Events

    /// A day's all-day events, and its timed events placed on the timeline.
    ///
    /// - Parameter minimumDuration: the shortest an event is drawn — and so
    ///   the space it claims when deciding what overlaps. Pass the time your
    ///   smallest readable tile represents, or 0.
    public static func layout<E: CalendarEvent>(_ events: [E], on date: Date, calendar: Calendar = .current,
                                                minimumDuration: TimeInterval = 0) -> DayLayout<E> {
        Placement.day(events, on: date, in: calendar, minimumDuration: minimumDuration)
    }

    /// Bars for events across a row of consecutive days, stacked in lanes.
    ///
    /// Pass the all-day events for a week view's top strip, or everything for
    /// a month row. With `maximumLanes`, events that do not fit are counted in
    /// ``LaneLayout/hidden`` instead.
    public static func lanes<E: CalendarEvent>(_ events: [E], across days: [Date], calendar: Calendar = .current,
                                               maximumLanes: Int? = nil) -> LaneLayout<E> {
        Placement.lanes(events, across: days, in: calendar, maximumLanes: maximumLanes)
    }

    /// The events touching each day — the dots under a month view's dates.
    /// All-day first, then by start.
    public static func events<E: CalendarEvent>(_ events: [E], on days: [Date], calendar: Calendar = .current) -> [[E]] {
        EventDays.byDay(events, days: days, in: calendar)
    }

    /// Events day by day, for a list view. Each event appears on every day it
    /// touches, cut to that day. Days with nothing on are left out unless
    /// `includeEmptyDays` is set.
    public static func agenda<E: CalendarEvent>(_ events: [E], on days: [Date], calendar: Calendar = .current,
                                                includeEmptyDays: Bool = false) -> [AgendaDay<E>] {
        Listings.agenda(events, days: days, in: calendar, includeEmptyDays: includeEmptyDays)
    }

    /// Bookings as rows on a board: one row per resource, in the order given,
    /// each with its bookings in lanes across the days, its free days, and
    /// the days it is double-booked.
    ///
    /// - Parameter resourceOf: which resource a booking belongs to. Bookings
    ///   for a resource not in `resources` are left off the board.
    public static func board<R: Hashable, E: CalendarEvent>(
        _ events: [E], resources: [R], resourceOf: (E) -> R, across days: [Date], calendar: Calendar = .current
    ) -> [BoardRow<R, E>] {
        Listings.board(events, resources: resources, resourceOf: resourceOf, days: days, in: calendar)
    }

    /// Repeating events turned into their occurrences within a range, ready
    /// for any view. One-off events come through as a single occurrence.
    ///
    /// Expand over the stretch a view can show — a few months either side of
    /// today is cheap — rather than per screen.
    public static func expand<E: RecurringEvent>(_ events: [E], in range: DateInterval,
                                                 calendar: Calendar = .current) -> [Occurrence<E>] {
        Recurrence.expand(events, in: range, calendar: calendar)
    }

    /// When a repeating series happens within a range: one interval per
    /// occurrence, keeping the first occurrence's wall-clock time.
    public static func occurrences(of rule: RecurrenceRule, start: Date, end: Date, isAllDay: Bool = false,
                                   in range: DateInterval, calendar: Calendar = .current) -> [DateInterval] {
        Recurrence.occurrences(of: rule, start: start, end: end, isAllDay: isAllDay, in: range, calendar: calendar)
    }

    /// The hour lines of a day's timeline, positioned the same way as
    /// ``layout(_:on:calendar:minimumDuration:)`` positions events.
    public static func hourMarks(on date: Date, every hours: Int = 1, calendar: Calendar = .current) -> [HourMark] {
        EventDays.hourMarks(on: date, every: hours, in: calendar)
    }

    // MARK: - Appointments

    /// The open stretches from one day to another, inclusive, as instants in
    /// the calendar's time zone.
    public static func openIntervals(_ hours: OpeningHours, from first: CalendarDay, through last: CalendarDay,
                                     calendar: Calendar = .current) -> [DateInterval] {
        OpeningTimes.intervals(hours, from: first, through: last, in: calendar.timeZone)
    }

    /// The gaps inside some windows that nothing busy covers.
    ///
    /// - Parameters:
    ///   - buffer: kept clear either side of each busy interval.
    ///   - minimumLength: gaps shorter than this are dropped.
    public static func freeTime(in windows: [DateInterval], busy: [DateInterval], buffer: TimeInterval = 0,
                                minimumLength: TimeInterval = 0) -> [DateInterval] {
        FreeTime.gaps(in: windows, busy: busy, buffer: buffer, minimumLength: minimumLength)
    }

    /// Bookable slots of a fixed length: one every `step` from the start of
    /// each window, kept when it fits inside the window and clashes with
    /// nothing. `step` defaults to the slot's own length.
    public static func slots(length: TimeInterval, every step: TimeInterval? = nil, in windows: [DateInterval],
                             busy: [DateInterval] = [], buffer: TimeInterval = 0) -> [DateInterval] {
        FreeTime.slots(length: length, every: step ?? length, in: windows, busy: busy, buffer: buffer)
    }

    /// The busy intervals a candidate overlaps, as indices. Touching is not
    /// overlapping, unless a buffer closes the gap.
    public static func clashes(_ candidate: DateInterval, with busy: [DateInterval], buffer: TimeInterval = 0) -> [Int] {
        FreeTime.clashes(candidate, with: busy, buffer: buffer)
    }

    /// Slots across several resources — rooms, staff, tables — each with
    /// its own open windows and bookings. A slot is offered when at least
    /// `minimumFree` resources are free for all of it. A resource with no
    /// windows is never free.
    public static func slots<R: Hashable & Sendable>(
        length: TimeInterval, every step: TimeInterval? = nil, resources: [R],
        windows: [R: [DateInterval]], busy: [R: [DateInterval]] = [:], buffer: TimeInterval = 0, minimumFree: Int = 1
    ) -> [ResourceSlot<R>] {
        FreeTime.resourceSlots(length: length, every: step ?? length, resources: resources, windows: windows,
                               busy: busy, buffer: buffer, minimumFree: minimumFree)
    }

    /// The timed events that clash: overlapping another, or closer to one
    /// than `buffer`, among events `sameGroup` says compete — the same room,
    /// the same person. All-day events are left out.
    public static func conflicts<E: CalendarEvent>(_ events: [E], buffer: TimeInterval = 0,
                                                   sameGroup: (E, E) -> Bool = { _, _ in true }) -> Set<E.ID> {
        FreeTime.conflicts(events, buffer: buffer, sameGroup: sameGroup)
    }

    /// The resources free for the whole of a candidate booking, in the order given.
    public static func freeResources<R: Hashable & Sendable>(
        for candidate: DateInterval, resources: [R], windows: [R: [DateInterval]], busy: [R: [DateInterval]] = [:],
        buffer: TimeInterval = 0
    ) -> [R] {
        FreeTime.freeResources(for: candidate, resources: resources, windows: windows, busy: busy, buffer: buffer)
    }

    /// Opening hours as week-at-a-glance lines, in the calendar's week order
    /// and its locale's clock.
    public static func summary(_ hours: OpeningHours, calendar: Calendar = .current, closedLabel: String = "Closed") -> [HoursLine] {
        HoursSummary.lines(hours, in: calendar, closedLabel: closedLabel)
    }

    // MARK: - Stays

    /// Whether a stay can be booked, and if not the first reason: bad
    /// dates, then too short (a season's minimum counts, judged by the
    /// check-in night), then too long, then clashes.
    public static func check(_ stay: Stay, against booked: [Stay] = [], rules: StayRules = StayRules(),
                             rates: NightlyRates? = nil) -> StayCheck {
        Stays.check(stay, against: booked, rules: rules, rates: rates)
    }

    /// Every night already taken.
    public static func bookedNights(_ stays: [Stay]) -> Set<CalendarDay> {
        Stays.bookedNights(stays)
    }

    /// The days from `first` to `last` a guest could check in for at least
    /// the minimum stay — the enabled days of a check-in picker.
    public static func checkInDays(from first: CalendarDay, through last: CalendarDay, booked: [Stay],
                                   rules: StayRules = StayRules(), rates: NightlyRates? = nil) -> [CalendarDay] {
        Stays.checkInDays(from: first, through: last, booked: booked, rules: rules, rates: rates)
    }

    /// The check-out days that make a bookable stay from a check-in — the
    /// enabled days once the first date is picked. Without a maximum stay it
    /// looks `searchLimit` nights ahead.
    public static func checkOutDays(after checkIn: CalendarDay, booked: [Stay], rules: StayRules = StayRules(),
                                    rates: NightlyRates? = nil, searchLimit: Int = 365) -> [CalendarDay] {
        Stays.checkOutDays(after: checkIn, booked: booked, rules: rules, rates: rates, searchLimit: searchLimit)
    }

    /// A stay priced night by night.
    public static func quote(_ stay: Stay, rates: NightlyRates) -> StayQuote {
        Stays.quote(stay, rates: rates)
    }
}
