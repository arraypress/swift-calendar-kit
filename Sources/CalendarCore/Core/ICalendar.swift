//
//  ICalendar.swift
//  CalendarCore
//
//  The namespace for iCalendar files; the reading and writing are in Support.
//

import Foundation

/// Reading and writing iCalendar (`.ics`) files.
public enum ICalendar {

    /// The events in an `.ics` file.
    ///
    /// Times come in three forms and all are read: a date (an all-day event),
    /// a UTC time (`…Z`), a time in a named zone (`TZID=Europe/London`), and a
    /// floating local time, read in `calendar`'s zone. Repeating events keep
    /// their rule; an occurrence edited separately (`RECURRENCE-ID`) becomes
    /// its own event and its date is skipped in the series. Alarms and other
    /// components are passed over.
    ///
    /// - Throws: ``TimetableError/notICalendar`` for text with no
    ///   `BEGIN:VCALENDAR` or `BEGIN:VEVENT` in it.
    public static func read(_ text: String, calendar: Calendar = .current) throws(TimetableError) -> ICalendarImport {
        try ICSReader.read(text, calendar: calendar)
    }

    /// An `.ics` file holding events, ready to save or share.
    ///
    /// A repeating event (a ``RecurringEvent`` with a rule) is written with its
    /// rule, and its times in `calendar`'s zone so 09:00 stays 09:00 across a
    /// clock change wherever it is opened; one-off times are written in UTC.
    /// Export the events you store, not expanded occurrences.
    ///
    /// - Parameters:
    ///   - name: the calendar's name, for apps that show one.
    ///   - stamp: when the file was made (`DTSTAMP`).
    public static func write<E: CalendarEvent>(
        _ events: [E], name: String? = nil, calendar: Calendar = .current, stamp: Date = .now,
        title: (E) -> String, notes: (E) -> String? = { _ in nil }, location: (E) -> String? = { _ in nil }
    ) -> String {
        ICSWriter.write(events, name: name, calendar: calendar, stamp: stamp, title: title, notes: notes, location: location)
    }

    /// An `.ics` file from events read out of one, as they were.
    public static func write(_ events: [ICalendarEvent], name: String? = nil, calendar: Calendar = .current,
                             stamp: Date = .now) -> String {
        ICSWriter.write(events, name: name, calendar: calendar, stamp: stamp, title: \.title, notes: \.notes, location: \.location)
    }
}
