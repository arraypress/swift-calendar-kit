//
//  Spoken.swift
//  CalendarUI
//
//  How events and their times are read aloud by VoiceOver.
//

import Foundation
import CalendarCore

/// How an event is read aloud: "Monday 5 October, 09:30 to 11:30, repeats".
enum Spoken {

    static func when<Event: CalendarEvent>(_ event: Event, calendar: Calendar) -> String {
        let day = { (date: Date) in calendar.format(date) { $0.weekday(.wide).day().month(.wide) } }
        let time = { (date: Date) in calendar.format(date) { $0.hour().minute() } }
        var parts: [String]
        if event.isAllDay {
            let last = event.end > event.start ? event.end.addingTimeInterval(-1) : event.start
            parts = calendar.isDate(event.start, inSameDayAs: last)
                ? [day(event.start), String(localized: "all day", bundle: .module)]
                : [String(localized: "\(day(event.start)) to \(day(last))", bundle: .module), String(localized: "all day", bundle: .module)]
        } else if calendar.isDate(event.start, inSameDayAs: event.end) || event.end <= event.start {
            parts = [day(event.start), String(localized: "\(time(event.start)) to \(time(event.end))", bundle: .module)]
        } else {
            parts = [String(localized: "\(day(event.start)) \(time(event.start)) to \(day(event.end)) \(time(event.end))", bundle: .module)]
        }
        if event.isRecurring { parts.append(String(localized: "repeats", bundle: .module)) }
        return parts.joined(separator: ", ")
    }
}
