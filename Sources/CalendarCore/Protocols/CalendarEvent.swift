//
//  CalendarEvent.swift
//  CalendarCore
//

import Foundation

/// Anything that occupies time on a calendar.
///
/// Conform your own model rather than converting to one of ours — a booking,
/// a shift or a transaction only needs to say when it starts, when it ends,
/// and whether it is a whole-day thing.
///
/// `end` is exclusive. An all-day event from 4 to 6 September ends at the
/// start of the 6th, the way EventKit and iCalendar both store it; one whose
/// `end` is not after `start` covers the day `start` falls on.
public protocol CalendarEvent: Identifiable {

    /// When the event begins.
    var start: Date { get }

    /// When it ends, exclusive.
    var end: Date { get }

    /// Whether it belongs in the all-day row rather than on the timeline.
    var isAllDay: Bool { get }

    /// Whether it is one of a repeating series — the ↻ badge, and the
    /// "this event or all events?" question when it is moved or deleted.
    /// A ``RecurringEvent`` answers from its rule; an event whose occurrences
    /// come already expanded, such as one from Apple Calendar, says so itself.
    var isRecurring: Bool { get }
}

extension CalendarEvent {

    /// Timed, unless a conformer says otherwise.
    public var isAllDay: Bool { false }
}
