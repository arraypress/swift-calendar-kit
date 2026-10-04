//
//  LaneLayout.swift
//  CalendarCore
//

import Foundation

/// Bars across a row of days — the all-day strip of a week view, or one week
/// of a month view — stacked into lanes so no two bars overlap.
public struct LaneLayout<Event: CalendarEvent> {

    /// The bars that fit, top lane first.
    public let bars: [LaneBar<Event>]

    /// How many lanes the bars use.
    public let laneCount: Int

    /// For each day, how many events did not fit under the lane limit — the
    /// number behind a "+2 more".
    public let hidden: [Int]
}

/// One event's bar in a ``LaneLayout``.
public struct LaneBar<Event: CalendarEvent>: Identifiable {

    /// The event.
    public let event: Event

    /// The zero-based lane, top first.
    public let lane: Int

    /// The first day it covers, as an index into the row's days.
    public let firstDay: Int

    /// The last day it covers, inclusive.
    public let lastDay: Int

    /// Whether it began before the row's first day — draw a cut edge.
    public let continuesBefore: Bool

    /// Whether it runs past the row's last day.
    public let continuesAfter: Bool

    /// How many days the bar spans.
    public var length: Int { lastDay - firstDay + 1 }

    /// The event's identity.
    public var id: Event.ID { event.id }
}

extension LaneLayout: Sendable where Event: Sendable {}
extension LaneBar: Sendable where Event: Sendable {}
extension LaneBar: Equatable where Event: Equatable {}
