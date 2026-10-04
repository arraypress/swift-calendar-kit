//
//  RecurringEvent.swift
//  CalendarCore
//

import Foundation

/// An event that may repeat, by a ChronoKit ``RecurrenceRule``. Expand a
/// list of them with ``Timetable/expand(_:in:calendar:)`` before handing
/// them to a view.
///
/// Read a rule from iCalendar text or from words — `try RecurrenceRule(parsing:
/// "FREQ=MONTHLY;BYDAY=-1FR")` or `"the last friday of every month"` — and
/// write it back with `rruleString`.
public protocol RecurringEvent: CalendarEvent {

    /// How the event repeats, or `nil` for a one-off.
    var recurrence: RecurrenceRule? { get }
}
