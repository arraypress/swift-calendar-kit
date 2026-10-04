//
//  BasicEvent.swift
//  CalendarCore
//

import Foundation

/// A ready-made ``CalendarEvent`` for when there is no model of your own yet.
public struct BasicEvent: CalendarEvent, Sendable, Hashable, Codable {

    /// A stable identifier.
    public var id: String

    /// What the event is called.
    public var title: String

    /// When it begins.
    public var start: Date

    /// When it ends, exclusive.
    public var end: Date

    /// Whether it is a whole-day event.
    public var isAllDay: Bool

    /// An event.
    public init(id: String = UUID().uuidString, title: String, start: Date, end: Date, isAllDay: Bool = false) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
    }
}
