//
//  BoardRow.swift
//  CalendarCore
//

import Foundation

/// One resource's row on a bookings board — a property, a room, a member of
/// staff — with its bookings laid out across the days.
///
/// Bookings that overlap within one row are double bookings; they stack in
/// extra lanes rather than hiding each other, and ``clashingDays`` says where.
public struct BoardRow<Resource: Hashable, Event: CalendarEvent>: Identifiable {

    /// The resource.
    public let resource: Resource

    /// Its bookings as bars across the board's days.
    public let lanes: LaneLayout<Event>

    /// For each day, whether nothing is booked.
    public let isFree: [Bool]

    /// The days, as indices, where two or more bookings overlap.
    public let clashingDays: [Int]

    /// Identified by the resource.
    public var id: Resource { resource }
}

extension BoardRow: Sendable where Resource: Sendable, Event: Sendable {}
