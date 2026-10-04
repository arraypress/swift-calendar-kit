//
//  ICalendar.swift
//  CalendarCore
//
//  RFC 5545 files in and out, for events: the content lines (folded,
//  escaped, with parameters), VEVENT's times in their three forms, and the
//  edited occurrences of a series. Repeat rules are ChronoKit's.
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

// MARK: - Content lines

/// One unfolded line: `DTSTART;TZID=Europe/London:20261004T090000`.
struct ContentLine {
    var name: String
    var parameters: [String: String]
    var value: String
    var raw: String

    init?(_ line: String) {
        var name = "", parameters: [String: String] = [:], current = "", key = ""
        var inQuotes = false, inName = true, seenColon = false
        var valueStart = line.endIndex
        for index in line.indices {
            let character = line[index]
            if character == "\"" { inQuotes.toggle(); continue }
            if inQuotes { current.append(character); continue }
            switch character {
            case ";":
                if inName { name = current; inName = false } else if !key.isEmpty { parameters[key.uppercased()] = current }
                current = ""; key = ""
            case "=" where !inName && key.isEmpty:
                key = current; current = ""
            case ":":
                if inName { name = current } else if !key.isEmpty { parameters[key.uppercased()] = current }
                valueStart = line.index(after: index)
                seenColon = true
            default:
                current.append(character)
            }
            if seenColon { break }
        }
        guard seenColon, !name.isEmpty else { return nil }
        self.name = name.uppercased()
        self.parameters = parameters
        self.value = String(line[valueStart...])
        self.raw = line
    }

    /// RFC 5545 §3.3.11 text, unescaped.
    var text: String {
        var result = "", escaping = false
        for character in value {
            if escaping {
                switch character {
                case "n", "N": result.append("\n")
                default: result.append(character)
                }
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                result.append(character)
            }
        }
        return result
    }

    /// Lines joined back where they were folded: a line starting with a space
    /// or tab continues the one before.
    static func unfold(_ text: String) -> [String] {
        var lines: [String] = []
        for line in text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n") {
            if let first = line.first, first == " " || first == "\t", !lines.isEmpty {
                lines[lines.count - 1] += line.dropFirst()
            } else if !line.isEmpty {
                lines.append(line)
            }
        }
        return lines
    }
}

// MARK: - Reading

enum ICSReader {

    static func read(_ text: String, calendar: Calendar) throws(TimetableError) -> ICalendarImport {
        let lines = ContentLine.unfold(text).compactMap(ContentLine.init)
        guard lines.contains(where: { $0.name == "BEGIN" && ["VCALENDAR", "VEVENT"].contains($0.value.uppercased()) }) else {
            throw .notICalendar
        }
        let name = lines.first { $0.name == "X-WR-CALNAME" }?.text

        // Gather each VEVENT's own lines, skipping nested components such as VALARM.
        var blocks: [[ContentLine]] = []
        var current: [ContentLine]?
        var depth = 0
        for line in lines {
            if line.name == "BEGIN" {
                if line.value.uppercased() == "VEVENT", current == nil { current = []; depth = 0; continue }
                if current != nil { depth += 1 }
            } else if line.name == "END" {
                if line.value.uppercased() == "VEVENT", depth == 0, let block = current { blocks.append(block); current = nil; continue }
                if current != nil { depth -= 1 }
            } else if depth == 0 {
                current?.append(line)
            }
        }

        var warnings: [String] = []
        var masters: [ICalendarEvent] = []
        var overrides: [(uid: String, replaces: Date, event: ICalendarEvent?)] = []

        for (index, block) in blocks.enumerated() {
            func first(_ key: String) -> ContentLine? { block.first { $0.name == key } }
            let title = first("SUMMARY")?.text ?? String(localized: "Untitled", bundle: .module)
            let uid = first("UID")?.text ?? "event-\(index + 1)"
            guard let startLine = first("DTSTART"), let start = moment(startLine, calendar: calendar) else {
                warnings.append(String(localized: "\(title): no readable start time, so it was left out", bundle: .module))
                continue
            }
            let end: Date = {
                if let endLine = first("DTEND"), let end = moment(endLine, calendar: calendar) { return max(end.date, start.date) }
                if let duration = first("DURATION").flatMap({ parseDuration($0.value) }) {
                    return calendar.date(byAdding: .day, value: duration.days, to: start.date)!.addingTimeInterval(duration.seconds)
                }
                return start.isDay ? calendar.date(byAdding: .day, value: 1, to: start.date)! : start.date
            }()
            let cancelled = first("STATUS")?.value.uppercased() == "CANCELLED"

            if let replaced = first("RECURRENCE-ID").flatMap({ moment($0, calendar: calendar) }) {
                let event = cancelled ? nil : ICalendarEvent(
                    id: "\(uid)#\(Int(replaced.date.timeIntervalSince1970))", title: title, start: start.date, end: end,
                    isAllDay: start.isDay, notes: first("DESCRIPTION")?.text, location: first("LOCATION")?.text,
                    url: first("URL").flatMap { URL(string: $0.value) })
                overrides.append((uid, replaced.date, event))
                continue
            }
            if cancelled {
                warnings.append(String(localized: "\(title): cancelled, so it was left out", bundle: .module))
                continue
            }

            var rule: RecurrenceRule?
            let ruleLines = block.filter { ["RRULE", "EXDATE", "RDATE"].contains($0.name) }
            if ruleLines.contains(where: { $0.name == "RRULE" }) {
                do {
                    rule = try RecurrenceRule(parsing: ruleLines.map(\.raw).joined(separator: "\n"))
                } catch {
                    warnings.append(String(localized: "\(title): its repeat rule could not be used (\(error.localizedDescription)), so it was imported as a single event", bundle: .module))
                }
            }
            masters.append(ICalendarEvent(id: uid, title: title, start: start.date, end: end, isAllDay: start.isDay, recurrence: rule,
                                          notes: first("DESCRIPTION")?.text, location: first("LOCATION")?.text,
                                          url: first("URL").flatMap { URL(string: $0.value) }))
        }

        // Edited occurrences: skipped in their series, and kept as events of their own.
        var events = masters
        var extras: [ICalendarEvent] = []
        for override in overrides {
            if let index = events.firstIndex(where: { $0.id == override.uid }), let rule = events[index].recurrence {
                events[index].recurrence = rule.skipping(override.replaces)
            }
            if let event = override.event { extras.append(event) }
        }
        return ICalendarImport(events: events + extras, warnings: warnings, name: name)
    }

    /// A `DATE` or `DATE-TIME` value: a day, a UTC time, a time in a TZID, or a floating local time.
    static func moment(_ line: ContentLine, calendar: Calendar) -> (date: Date, isDay: Bool)? {
        let value = line.value.trimmingCharacters(in: .whitespaces)
        let isDay = line.parameters["VALUE"]?.uppercased() == "DATE" || (value.count == 8 && !value.contains("T"))
        var zone = calendar.timeZone
        if value.hasSuffix("Z") { zone = TimeZone(identifier: "UTC")! }
        else if let id = line.parameters["TZID"], let named = TimeZone(identifier: id) { zone = named }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = isDay ? calendar.timeZone : zone
        formatter.dateFormat = isDay ? "yyyyMMdd" : (value.hasSuffix("Z") ? "yyyyMMdd'T'HHmmss'Z'" : "yyyyMMdd'T'HHmmss")
        guard let date = formatter.date(from: isDay ? String(value.prefix(8)) : value) else { return nil }
        return (isDay ? calendar.startOfDay(for: date) : date, isDay)
    }

    /// `P1W`, `P2D`, `PT1H30M`, `P1DT12H` — RFC 5545 §3.3.6; days kept apart
    /// from seconds so a day stays a calendar day across a clock change.
    static func parseDuration(_ text: String) -> (days: Int, seconds: TimeInterval)? {
        var body = text.uppercased()
        let negative = body.hasPrefix("-")
        if body.hasPrefix("-") || body.hasPrefix("+") { body.removeFirst() }
        guard body.hasPrefix("P") else { return nil }
        body.removeFirst()
        var days = 0, seconds: TimeInterval = 0, number = "", inTime = false
        for character in body {
            if character.isNumber { number.append(character); continue }
            if character == "T" { inTime = true; continue }
            guard let value = Int(number) else { return nil }
            number = ""
            switch (character, inTime) {
            case ("W", false): days += value * 7
            case ("D", false): days += value
            case ("H", true): seconds += TimeInterval(value * 3600)
            case ("M", true): seconds += TimeInterval(value * 60)
            case ("S", true): seconds += TimeInterval(value)
            default: return nil
            }
        }
        return negative ? nil : (days, seconds)
    }
}

// MARK: - Writing

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
