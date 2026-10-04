//
//  AppleCalendar.swift
//  CalendarEventKit
//
//  Reading Apple Calendar into the views, and writing the views' edits back.
//

#if canImport(EventKit) && !os(tvOS)
import EventKit
import CalendarCore

/// Apple Calendar, for the calendar views: events in, edits out.
///
/// ```swift
/// let apple = AppleCalendar()
/// try await apple.requestAccess()
/// let events = apple.events(in: visibleStretch)
///
/// WeekView(events: events, date: $date, title: \.title, tint: \.color)
///     .calendarEditing(AppleCalendarEvent.self, selection: $selected,
///         onReschedule: { event, interval, scope in try? apple.reschedule(event, to: interval, scope: scope) },
///         onDelete: { event, scope in try? apple.delete(event, scope: scope) })
/// ```
///
/// Your app needs `NSCalendarsFullAccessUsageDescription` in its Info.plist
/// before asking. EventKit is not thread-safe, so this lives on the main actor.
@MainActor
public final class AppleCalendar {

    /// The store everything goes through.
    public let store: EKEventStore

    /// Apple Calendar through a store, a new one unless given.
    public init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    /// Asks for full access to events. True when granted.
    @discardableResult
    public func requestAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }

    /// Whether full access has been granted.
    public var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    /// The calendars events can be read from.
    public var calendars: [EKCalendar] { store.calendars(for: .event) }

    /// Every occurrence overlapping a stretch of time, from all calendars or some.
    public func events(in range: DateInterval, calendars: [EKCalendar]? = nil) -> [AppleCalendarEvent] {
        let predicate = store.predicateForEvents(withStart: range.start, end: range.end, calendars: calendars)
        return store.events(matching: predicate).map(AppleCalendarEvent.init)
    }

    #if !os(watchOS)
    // Writing: Apple Watch reads calendars but cannot change them.

    /// Moves or resizes an event, as a calendar view's `onReschedule` reports it.
    ///
    /// `.thisEvent` changes the one occurrence; `.thisAndFollowing` this and
    /// every later one; `.allEvents` shifts the whole series by the same
    /// amount from its first occurrence, which EventKit has no single span for.
    public func reschedule(_ event: AppleCalendarEvent, to interval: DateInterval, scope: EditScope) throws {
        if scope == .allEvents, event.isRecurring, let first = store.event(withIdentifier: event.eventIdentifier) {
            let shift = interval.start.timeIntervalSince(event.start)
            let stretch = interval.duration - event.end.timeIntervalSince(event.start)
            first.startDate = first.startDate.addingTimeInterval(shift)
            first.endDate = first.endDate.addingTimeInterval(shift + stretch)  // all-day ends stay at 23:59:59
            try store.save(first, span: .futureEvents)
            return
        }
        let occurrence = try find(event)
        occurrence.startDate = interval.start
        occurrence.endDate = event.isAllDay ? EventKitRules.inclusiveEnd(interval.end, start: interval.start) : interval.end
        try store.save(occurrence, span: scope == .thisEvent ? .thisEvent : .futureEvents)
    }

    /// Deletes an event, as a calendar view's `onDelete` reports it.
    public func delete(_ event: AppleCalendarEvent, scope: EditScope) throws {
        if scope == .allEvents, event.isRecurring, let first = store.event(withIdentifier: event.eventIdentifier) {
            try store.remove(first, span: .futureEvents)
            return
        }
        try store.remove(try find(event), span: scope == .thisEvent ? .thisEvent : .futureEvents)
    }

    /// Adds an event, as a calendar view's `onCreate` reports it, to a
    /// calendar or the default one for new events.
    @discardableResult
    public func create(title: String, in interval: DateInterval, isAllDay: Bool = false,
                       calendar: EKCalendar? = nil) throws -> AppleCalendarEvent {
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = interval.start
        event.endDate = isAllDay ? EventKitRules.inclusiveEnd(interval.end, start: interval.start) : interval.end
        event.isAllDay = isAllDay
        event.calendar = calendar ?? store.defaultCalendarForNewEvents
        try store.save(event, span: .thisEvent)
        return AppleCalendarEvent(event)
    }

    #endif

    /// The live occurrence behind a value: same identifier, same start.
    private func find(_ event: AppleCalendarEvent) throws -> EKEvent {
        let predicate = store.predicateForEvents(withStart: event.start.addingTimeInterval(-1),
                                                 end: max(event.end, event.start).addingTimeInterval(1), calendars: nil)
        // An all-day value's end is the next midnight; EventKit's own is a second before.
        if let match = store.events(matching: predicate).first(where: {
            $0.eventIdentifier == event.eventIdentifier && $0.startDate == event.start
        }) {
            return match
        }
        throw AppleCalendarError.notFound(event.title)
    }
}

/// Something Apple Calendar would not do.
public enum AppleCalendarError: Error, Sendable, Equatable, CustomStringConvertible {

    /// The event is no longer in Apple Calendar — deleted or moved elsewhere since it was read.
    case notFound(String)

    public var description: String {
        switch self {
        case .notFound(let title): "\"\(title)\" is no longer in Apple Calendar; read the events again"
        }
    }
}
#endif
