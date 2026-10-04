//
//  AppleCalendarEvent.swift
//  CalendarEventKit
//
//  An event from Apple Calendar, as a value the calendar views can show.
//

#if canImport(EventKit) && !os(tvOS)
import EventKit
import SwiftUI
import CalendarCore

/// One occurrence of an Apple Calendar event, detached from its `EKEvent`.
///
/// EventKit hands back repeating events already expanded, and gives every
/// occurrence of a series the same identifier; this pairs it with the
/// occurrence's start so each one is distinct in a view. Repeating events
/// report ``isRecurring`` and their rule, so they carry the ↻ badge and edits
/// ask "this event or all events?" — but they are not a ``RecurringEvent``,
/// because EventKit has expanded them already.
public struct AppleCalendarEvent: CalendarEvent, Sendable, Hashable {

    /// EventKit's identifier and this occurrence's start.
    public struct ID: Hashable, Sendable {
        public let identifier: String
        public let start: Date
    }

    public let id: ID

    /// `EKEvent.eventIdentifier`: the same for every occurrence of a series.
    public let eventIdentifier: String

    /// The event's title.
    public let title: String

    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let isRecurring: Bool

    /// The series' rule as ChronoKit reads it, when it repeats and the rule
    /// is one ChronoKit can say — for "Every Monday" in the details card.
    public let recurrence: RecurrenceRule?

    /// The calendar it is in, and that calendar's colour.
    public let calendarTitle: String
    public let calendarIdentifier: String
    let colorComponents: [Double]?

    public let location: String?
    public let notes: String?
    public let url: URL?

    /// The calendar's colour, as Calendar.app shows it.
    public var color: Color {
        guard let c = colorComponents, c.count >= 3 else { return .accentColor }
        return Color(.sRGB, red: c[0], green: c[1], blue: c[2], opacity: c.count > 3 ? c[3] : 1)
    }

    /// A value from an `EKEvent` occurrence.
    public init(_ event: EKEvent) {
        let identifier = event.eventIdentifier ?? event.calendarItemIdentifier
        id = ID(identifier: identifier, start: event.startDate)
        eventIdentifier = identifier
        title = event.title?.isEmpty == false ? event.title! : String(localized: "New Event")
        start = event.startDate
        end = event.isAllDay ? EventKitRules.exclusiveEnd(of: event) : event.endDate
        isAllDay = event.isAllDay
        isRecurring = event.hasRecurrenceRules
        recurrence = event.recurrenceRules?.first.flatMap(EventKitRules.rule)
        calendarTitle = event.calendar?.title ?? ""
        calendarIdentifier = event.calendar?.calendarIdentifier ?? ""
        colorComponents = event.calendar?.cgColor.flatMap(EventKitRules.components)
        location = event.location
        notes = event.notes
        url = event.url
    }
}

/// Translating between EventKit's rule objects and ChronoKit's.
enum EventKitRules {

    /// `EKRecurrenceRule` describes itself with its RFC 5545 text —
    /// `EKRecurrenceRule <0x…> RRULE FREQ=WEEKLY;INTERVAL=2;BYDAY=MO` — which
    /// ChronoKit reads. A rule it cannot read gives nil, not a wrong rule.
    static func rule(_ rule: EKRecurrenceRule) -> RecurrenceRule? {
        let description = rule.description
        guard let range = description.range(of: "RRULE ") else { return nil }
        let text = description[range.upperBound...].split(separator: " ").first.map(String.init) ?? ""
        return try? RecurrenceRule(parsing: text)
    }

    /// EventKit ends an all-day event at 23:59:59 on its last day; the views
    /// end it at the next midnight, as iCalendar does.
    static func exclusiveEnd(of event: EKEvent) -> Date {
        let calendar = Calendar.current
        let lastDay = calendar.startOfDay(for: event.endDate)
        if event.endDate == lastDay, event.endDate > event.startDate { return lastDay }
        return calendar.date(byAdding: .day, value: 1, to: lastDay) ?? event.endDate
    }

    /// And back: the last second of the last day, for an all-day end at midnight.
    static func inclusiveEnd(_ end: Date, start: Date) -> Date {
        end > start ? end.addingTimeInterval(-1) : end
    }

    static func components(_ color: CGColor) -> [Double]? {
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = color.converted(to: srgb, intent: .defaultIntent, options: nil),
              let parts = converted.components else { return nil }
        return parts.map(Double.init)
    }
}
#endif
