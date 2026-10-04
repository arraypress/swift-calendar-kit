//
//  Fixtures.swift
//  CalendarCore
//
//  Fixed zones, fixed locales, fixed dates. A suite that asks the machine
//  what day it is passes on the day it was written. September 2026: the 1st
//  is a Tuesday and the 4th a Friday.
//

import Foundation
@testable import CalendarCore

let utc = TimeZone(identifier: "UTC")!
let london = TimeZone(identifier: "Europe/London")!
let auckland = TimeZone(identifier: "Pacific/Auckland")!

func calendar(_ zone: TimeZone = utc, firstWeekday: Int = 2, locale: String = "en_GB") -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    calendar.locale = Locale(identifier: locale)  // before firstWeekday: setting a locale resets it
    calendar.firstWeekday = firstWeekday
    return calendar
}

/// `2026-09-04` or `2026-09-04T09:30`, read in a zone.
func at(_ text: String, _ zone: TimeZone = utc) -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = zone
    formatter.dateFormat = text.contains("T") ? "yyyy-MM-dd'T'HH:mm" : "yyyy-MM-dd"
    return formatter.date(from: text)!
}

func day(_ text: String) -> CalendarDay {
    let parts = text.split(separator: "-").map { Int($0)! }
    return try! CalendarDay(year: parts[0], month: parts[1], day: parts[2])
}

func interval(_ from: String, _ to: String, _ zone: TimeZone = utc) -> DateInterval {
    DateInterval(start: at(from, zone), end: at(to, zone))
}

func event(_ id: String, _ from: String, _ to: String, allDay: Bool = false, _ zone: TimeZone = utc) -> BasicEvent {
    BasicEvent(id: id, title: id, start: at(from, zone), end: at(to, zone), isAllDay: allDay)
}

let hour: TimeInterval = 3600
