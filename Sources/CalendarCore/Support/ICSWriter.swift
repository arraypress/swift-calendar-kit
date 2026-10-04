//
//  ICSWriter.swift
//  CalendarCore
//
//  Events into a file: dates or zoned or UTC times, text escaped, lines
//  folded at 75 octets, CRLF throughout.
//

import Foundation

enum ICSWriter {

    static func write<E: CalendarEvent>(_ events: [E], name: String?, calendar: Calendar, stamp: Date,
                                        title: (E) -> String, notes: (E) -> String?, location: (E) -> String?) -> String {
        var lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//arraypress//swift-calendar-kit//EN", "CALSCALE:GREGORIAN"]
        if let name { lines.append("X-WR-CALNAME:" + escape(name)) }
        for event in events {
            let rule = (event as? any RecurringEvent)?.recurrence
            lines.append("BEGIN:VEVENT")
            lines.append("UID:" + escape("\(event.id)"))
            lines.append("DTSTAMP:" + utc(stamp))
            if event.isAllDay {
                let end = event.end > event.start ? event.end : calendar.date(byAdding: .day, value: 1, to: event.start)!
                lines.append("DTSTART;VALUE=DATE:" + day(event.start, calendar))
                lines.append("DTEND;VALUE=DATE:" + day(end, calendar))
            } else if rule != nil {
                let zone = calendar.timeZone.identifier
                lines.append("DTSTART;TZID=\(zone):" + local(event.start, calendar))
                lines.append("DTEND;TZID=\(zone):" + local(max(event.end, event.start), calendar))
            } else {
                lines.append("DTSTART:" + utc(event.start))
                lines.append("DTEND:" + utc(max(event.end, event.start)))
            }
            lines.append("SUMMARY:" + escape(title(event)))
            if let text = notes(event), !text.isEmpty { lines.append("DESCRIPTION:" + escape(text)) }
            if let text = location(event), !text.isEmpty { lines.append("LOCATION:" + escape(text)) }
            if let ruleLines = rule?.icsLines { lines += ruleLines }
            lines.append("END:VEVENT")
        }
        lines.append("END:VCALENDAR")
        return lines.map(fold).joined(separator: "\r\n") + "\r\n"
    }

    /// RFC 5545 §3.3.11: backslash, semicolon, comma and newline escaped.
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    /// Lines over 75 octets folded with a leading space, never inside a character.
    static func fold(_ line: String) -> String {
        guard line.utf8.count > 75 else { return line }
        var parts: [String] = [], current = "", size = 0
        for character in line {
            let width = String(character).utf8.count
            let limit = parts.isEmpty ? 75 : 74
            if size + width > limit {
                parts.append(current)
                current = ""
                size = 0
            }
            current.append(character)
            size += width
        }
        parts.append(current)
        return parts.joined(separator: "\r\n ")
    }

    static func formatter(_ format: String, _ zone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = zone
        formatter.dateFormat = format
        return formatter
    }

    static func utc(_ date: Date) -> String { formatter("yyyyMMdd'T'HHmmss'Z'", TimeZone(identifier: "UTC")!).string(from: date) }
    static func local(_ date: Date, _ calendar: Calendar) -> String { formatter("yyyyMMdd'T'HHmmss", calendar.timeZone).string(from: date) }
    static func day(_ date: Date, _ calendar: Calendar) -> String { formatter("yyyyMMdd", calendar.timeZone).string(from: date) }
}
