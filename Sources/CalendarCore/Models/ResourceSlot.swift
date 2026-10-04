//
//  ResourceSlot.swift
//  CalendarCore
//

import Foundation

/// A bookable slot, and which of several rooms, staff or tables are free for it.
public struct ResourceSlot<Resource: Hashable & Sendable>: Sendable, Hashable {

    /// When the slot runs.
    public let interval: DateInterval

    /// The resources free for the whole slot, in the order they were listed.
    public let free: [Resource]
}
