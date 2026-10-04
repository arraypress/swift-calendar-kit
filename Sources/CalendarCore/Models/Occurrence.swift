//
//  Occurrence.swift
//  CalendarCore
//

import Foundation

/// One occurrence of a ``RecurringEvent``: the event, moved to when this
/// occurrence happens. A one-off event expands to a single occurrence of itself.
public struct Occurrence<Event: RecurringEvent>: CalendarEvent {

    /// The event this is an occurrence of.
    public let event: Event

    /// When this occurrence starts.
    public let start: Date

    /// When it ends.
    public let end: Date

    /// Identifies the occurrence: the event and its start.
    public struct ID: Hashable {
        public let event: Event.ID
        public let start: Date
    }

    public var id: ID { ID(event: event.id, start: start) }

    public var isAllDay: Bool { event.isAllDay }
}

extension Occurrence: Sendable where Event: Sendable, Event.ID: Sendable {}
extension Occurrence.ID: Sendable where Event.ID: Sendable {}
extension Occurrence: Equatable where Event: Equatable {
    public static func == (a: Occurrence, b: Occurrence) -> Bool { a.event == b.event && a.start == b.start && a.end == b.end }
}
