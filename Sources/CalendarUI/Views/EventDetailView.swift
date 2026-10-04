//
//  EventDetailView.swift
//  CalendarUI
//

import SwiftUI

/// The standard details card: a title in its colour, when it happens and for
/// how long, how it repeats, and room underneath for your own content —
/// a guest's phone number, a price, buttons.
public struct EventDetailView<Extra: View>: View {

    private let title: String
    private let tint: Color
    private let when: String
    private let length: String?
    private let repeats: String?
    private let extra: Extra

    /// Details for any event.
    ///
    /// - Parameter recurrence: how it repeats, if it does. An ``Occurrence``
    ///   fills this in itself through the other initialiser.
    public init<Event: CalendarEvent>(
        _ event: Event, title: String, tint: Color = .accentColor, calendar: Calendar = .current,
        recurrence: RecurrenceRule? = nil, seriesStart: Date? = nil, @ViewBuilder extra: () -> Extra
    ) {
        self.title = title
        self.tint = tint
        (when, length) = Self.timing(start: event.start, end: event.end, isAllDay: event.isAllDay, calendar: calendar)
        repeats = recurrence?.phrase(from: seriesStart ?? event.start, calendar: calendar)
        self.extra = extra()
    }

    /// Details for one occurrence of a repeating event, with its rule in words.
    public init<Event: RecurringEvent>(
        _ occurrence: Occurrence<Event>, title: String, tint: Color = .accentColor, calendar: Calendar = .current,
        @ViewBuilder extra: () -> Extra
    ) {
        self.init(occurrence, title: title, tint: tint, calendar: calendar, recurrence: occurrence.recurrence,
                  seriesStart: occurrence.event.start, extra: extra)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 5)
                Text(title)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                Label(when, systemImage: "calendar")
                if let length { Label(length, systemImage: "clock") }
                if let repeats { Label(repeats, systemImage: "repeat") }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            extra
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "Sunday 4 October 2026, 09:00–10:00" and "1 hr"; "4–8 October 2026"
    /// and "4 days, all day".
    static func timing(start: Date, end: Date, isAllDay: Bool, calendar: Calendar) -> (String, String?) {
        let longDay = { (date: Date) in calendar.format(date) { $0.weekday(.wide).day().month(.wide).year() } }
        if isAllDay {
            let lastDay = end > start ? calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: end))! : start
            let days = (calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: lastDay).day ?? 0) + 1
            let when = calendar.isDate(start, inSameDayAs: lastDay)
                ? longDay(start)
                : "\(calendar.format(start) { $0.day().month(.abbreviated) }) – \(calendar.format(lastDay) { $0.day().month(.abbreviated).year() })"
            return (when, days == 1 ? String(localized: "All day", bundle: .module) : String(localized: "\(days) days, all day", bundle: .module))
        }
        let length = Duration.seconds(max(end.timeIntervalSince(start), 0))
            .formatted(.units(allowed: [.days, .hours, .minutes], width: .abbreviated))
        let time = { (date: Date) in calendar.format(date) { $0.hour().minute() } }
        let when = calendar.isDate(start, inSameDayAs: end) || end <= start
            ? "\(longDay(start)), \(time(start))–\(time(end))"
            : "\(calendar.format(start) { $0.weekday(.abbreviated).day().month(.abbreviated) }), \(time(start)) – "
                + "\(calendar.format(end) { $0.weekday(.abbreviated).day().month(.abbreviated) }), \(time(end))"
        return (when, end > start ? length : nil)
    }
}

extension EventDetailView where Extra == EmptyView {

    /// Details for any event, with nothing extra.
    public init<Event: CalendarEvent>(_ event: Event, title: String, tint: Color = .accentColor, calendar: Calendar = .current,
                                      recurrence: RecurrenceRule? = nil) {
        self.init(event, title: title, tint: tint, calendar: calendar, recurrence: recurrence) { EmptyView() }
    }

    /// Details for one occurrence of a repeating event, with nothing extra.
    public init<Event: RecurringEvent>(_ occurrence: Occurrence<Event>, title: String, tint: Color = .accentColor,
                                       calendar: Calendar = .current) {
        self.init(occurrence, title: title, tint: tint, calendar: calendar) { EmptyView() }
    }
}
