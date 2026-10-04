//
//  ContentLine.swift
//  CalendarCore
//

import Foundation

/// One unfolded iCalendar line: `DTSTART;TZID=Europe/London:20261004T090000`.
struct ContentLine {

    /// The property name, upper-cased: `DTSTART`.
    var name: String

    /// Its parameters, keys upper-cased: `["TZID": "Europe/London"]`.
    var parameters: [String: String]

    /// The raw value, still escaped: `20261004T090000`.
    var value: String

    /// The whole line as read.
    var raw: String
}
