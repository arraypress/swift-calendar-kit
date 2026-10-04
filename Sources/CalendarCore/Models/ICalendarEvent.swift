//
//  ICalendarEvent.swift
//  CalendarCore
//

import Foundation

/// An event read from an `.ics` file — a `VEVENT`.
public struct ICalendarEvent: RecurringEvent, Sendable, Hashable {

    /// The event's `UID`; for an edited occurrence, the series' UID and the
    /// occurrence it replaces.
    public var id: String

    /// `SUMMARY`.
    public var title: String

    /// `DTSTART`.
    public var start: Date

    /// `DTEND`, or `DTSTART` plus `DURATION`.
    public var end: Date

    /// Whether `DTSTART` is a date rather than a time.
    public var isAllDay: Bool

    /// `RRULE` with its `EXDATE` and `RDATE`s; occurrences edited separately
    /// in the file are already skipped here and imported as their own events.
    public var recurrence: RecurrenceRule?

    /// `DESCRIPTION`.
    public var notes: String?

    /// `LOCATION`.
    public var location: String?

    /// `URL`.
    public var url: URL?

    /// An event.
    public init(id: String, title: String, start: Date, end: Date, isAllDay: Bool = false, recurrence: RecurrenceRule? = nil,
                notes: String? = nil, location: String? = nil, url: URL? = nil) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.recurrence = recurrence
        self.notes = notes
        self.location = location
        self.url = url
    }
}

/// What reading an `.ics` file produced: its events, and what could not be
/// carried over exactly — said, never silently dropped.
public struct ICalendarImport: Sendable {

    /// The events, in file order.
    public let events: [ICalendarEvent]

    /// One line per thing that changed in the reading: "Standup: BYWEEKNO is
    /// not supported, so it was imported as a single event".
    public let warnings: [String]

    /// The calendar's own name, from `X-WR-CALNAME`, if it has one.
    public let name: String?
}
