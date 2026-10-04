//
//  Recurrence.swift
//  CalendarCore
//
//  Repeating events, expanded by ChronoKit's engine in the caller's calendar.
//  What is left here is the event side: how long each occurrence lasts, and
//  which ones a range can see.
//

import Foundation

extension Timetable {

    /// Repeating events turned into their occurrences within a range, ready
    /// for any view. One-off events come through as a single occurrence.
    ///
    /// Expand over the stretch a view can show — a few months either side of
    /// today is cheap — rather than per screen.
    public static func expand<E: RecurringEvent>(_ events: [E], in range: DateInterval,
                                                 calendar: Calendar = .current) -> [Occurrence<E>] {
        Recurrence.expand(events, in: range, calendar: calendar)
    }

    /// When a repeating series happens within a range: one interval per
    /// occurrence, keeping the first occurrence's wall-clock time.
    public static func occurrences(of rule: RecurrenceRule, start: Date, end: Date, isAllDay: Bool = false,
                                   in range: DateInterval, calendar: Calendar = .current) -> [DateInterval] {
        Recurrence.occurrences(of: rule, start: start, end: end, isAllDay: isAllDay, in: range, calendar: calendar)
    }
}

enum Recurrence {

    /// Every occurrence of a series that overlaps `range`, in order.
    static func occurrences(of rule: RecurrenceRule, start: Date, end: Date, isAllDay: Bool,
                            in range: DateInterval, calendar: Calendar) -> [DateInterval] {
        let firstDay = calendar.startOfDay(for: start)
        let dayLength = isAllDay ? max(calendar.dateComponents([.day], from: firstDay, to: calendar.startOfDay(for: end)).day ?? 1, 1) : 0
        let duration = isAllDay ? 0 : max(end.timeIntervalSince(start), 0)

        // An occurrence still running when the range opens began up to its own length earlier.
        let lower = isAllDay
            ? calendar.date(byAdding: .day, value: -dayLength, to: calendar.startOfDay(for: range.start)) ?? range.start
            : range.start.addingTimeInterval(-duration)

        return Chrono.occurrences(of: rule, from: start, between: lower, and: range.end, calendar: calendar).compactMap { begins in
            let ends = isAllDay ? calendar.date(byAdding: .day, value: dayLength, to: calendar.startOfDay(for: begins))! : begins.addingTimeInterval(duration)
            let overlaps = ends > begins
                ? begins < range.end && ends > range.start
                : begins >= range.start && begins < range.end
            return overlaps ? DateInterval(start: begins, end: ends) : nil
        }
    }

    static func expand<E: RecurringEvent>(_ events: [E], in range: DateInterval, calendar: Calendar) -> [Occurrence<E>] {
        events.flatMap { event -> [Occurrence<E>] in
            guard let rule = event.recurrence else {
                return EventDays.touches(event, range, in: calendar) ? [Occurrence(event: event, start: event.start, end: event.end)] : []
            }
            return occurrences(of: rule, start: event.start, end: event.end, isAllDay: event.isAllDay, in: range, calendar: calendar)
                .map { Occurrence(event: event, start: $0.start, end: $0.end) }
        }
        .sorted { ($0.start, $0.end) < ($1.start, $1.end) }
    }
}

/// ChronoKit's phrase, with the parts a rule leaves to its first occurrence
/// spelt out so a reader is not left asking "every week on which day?".
enum Phrasing {

    static func describe(_ rule: RecurrenceRule, from start: Date, calendar: Calendar) -> String {
        if let localized = PhraseLanguages.describe(rule, from: start, calendar: calendar) { return localized }
        let weekday = Weekday(rawValue: calendar.component(.weekday, from: start)) ?? .monday
        let day = calendar.component(.day, from: start)
        let unsaid = rule.byDay.isEmpty && rule.byMonthDay.isEmpty && rule.bySetPos.isEmpty && rule.businessDayOrdinal == nil

        let filled: RecurrenceRule?
        switch rule.frequency {
        case .weekly where rule.byDay.isEmpty:
            filled = rebuilt(rule, byDay: [WeekdayRule(weekday: weekday)])
        case .monthly where unsaid:
            filled = rebuilt(rule, byMonthDay: [day])
        case .yearly where unsaid && rule.byMonth.isEmpty:
            let date = start.formatted(Date.FormatStyle(date: .omitted, time: .omitted, locale: calendar.locale ?? .current,
                                                        calendar: calendar, timeZone: calendar.timeZone).day().month(.wide))
            return capitalised(rule.phrase.replacingOccurrences(of: "every year", with: "every year on \(date)"))
        default:
            filled = nil
        }
        return capitalised((filled ?? rule).phrase)
    }

    private static func rebuilt(_ rule: RecurrenceRule, byDay: [WeekdayRule]? = nil, byMonthDay: [Int]? = nil) -> RecurrenceRule? {
        try? RecurrenceRule(
            frequency: rule.frequency, interval: rule.interval, byDay: byDay ?? rule.byDay, byMonthDay: byMonthDay ?? rule.byMonthDay,
            byMonth: rule.byMonth, bySetPos: rule.bySetPos, count: rule.count, until: rule.until, weekStart: rule.weekStart,
            businessDayOrdinal: rule.businessDayOrdinal, exceptions: rule.exceptions, additions: rule.additions
        )
    }

    private static func capitalised(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }
}
