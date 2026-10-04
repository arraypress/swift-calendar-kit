//
//  DayLayout.swift
//  CalendarCore
//

import Foundation

/// Everything a day view draws: the all-day row, and where each timed event
/// sits on the timeline.
public struct DayLayout<Event: CalendarEvent> {

    /// The day, from its first instant to the next day's. 23 or 25 hours long
    /// across a clock change.
    public let day: DateInterval

    /// All-day events touching the day, earliest first.
    public let allDay: [Event]

    /// Timed events touching the day, placed.
    public let timed: [TimedPlacement<Event>]
}

/// Where a timed event sits in a day column.
///
/// Positions are fractions of the day, so a view multiplies by its own height
/// and width. Overlapping events share the width: an event in `column` 1 of 3
/// starts a third of the way across. `span` lets an event widen into columns
/// to its right that are free for its whole length, the way Calendar.app
/// does, so three events where only two ever overlap are not all squeezed to
/// a third.
public struct TimedPlacement<Event: CalendarEvent>: Identifiable {

    /// The event.
    public let event: Event

    /// Where it starts within this day: the event's start, or the day's.
    public let start: Date

    /// Where it ends within this day: the event's end, or the day's.
    public let end: Date

    /// The zero-based column in its group of overlapping events.
    public let column: Int

    /// How many columns its overlapping group needs.
    public let columns: Int

    /// How many columns it can fill, starting at `column`; at least 1.
    public let span: Int

    /// The top edge as a fraction of the day, 0 to 1.
    public let top: Double

    /// The height as a fraction of the day, after any minimum duration.
    public let height: Double

    /// Whether the event started on an earlier day.
    public let continuesFromPreviousDay: Bool

    /// Whether the event runs on into a later day.
    public let continuesToNextDay: Bool

    /// The event's identity.
    public var id: Event.ID { event.id }
}

/// An hour line on a day's timeline.
public struct HourMark: Sendable, Hashable, Identifiable {

    /// The instant the line marks.
    public let date: Date

    /// The wall-clock hour it reads: twice 1 on the autumn clock change, no 1
    /// in the spring.
    public let hour: Int

    /// How far down the day it sits, 0 to 1.
    public let position: Double

    /// Identified by its instant.
    public var id: Date { date }
}

extension DayLayout: Sendable where Event: Sendable {}
extension TimedPlacement: Sendable where Event: Sendable {}
extension TimedPlacement: Equatable where Event: Equatable {}
