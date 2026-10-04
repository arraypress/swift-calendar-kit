//
//  AgendaDay.swift
//  CalendarCore
//

import Foundation

/// One day of a list view, and what happens on it.
public struct AgendaDay<Event: CalendarEvent>: Identifiable {

    /// The day, from its first instant to the next day's.
    public let day: DateInterval

    /// The day's events: all-day first, then by start.
    public let entries: [AgendaEntry<Event>]

    /// Identified by the day's first instant.
    public var id: Date { day.start }
}

/// An event as it appears on one day of a list.
///
/// A flight from 22:00 to 06:00 shows on two days: from 22:00 on the first,
/// until 06:00 on the second. `start` and `end` are the part on this day.
public struct AgendaEntry<Event: CalendarEvent>: Identifiable {

    /// The event.
    public let event: Event

    /// Where it starts within the day.
    public let start: Date

    /// Where it ends within the day.
    public let end: Date

    /// Whether it began on an earlier day.
    public let continuesFromPreviousDay: Bool

    /// Whether it runs on into a later day.
    public let continuesToNextDay: Bool

    /// Whether it should read "All day": an all-day event, or a timed one
    /// that fills this day from midnight to midnight.
    public let isAllDay: Bool

    /// Which of the event's days this is, from 1 — the 2 in "Day 2 of 5".
    public let dayOfEvent: Int

    /// How many days the event touches in all — the 5 in "Day 2 of 5".
    public let eventDayCount: Int

    /// The event's identity.
    public var id: Event.ID { event.id }
}

extension AgendaDay: Sendable where Event: Sendable {}
extension AgendaEntry: Sendable where Event: Sendable {}
extension AgendaEntry: Equatable where Event: Equatable {}
