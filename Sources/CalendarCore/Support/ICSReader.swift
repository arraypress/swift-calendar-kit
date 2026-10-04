//
//  ICSReader.swift
//  CalendarCore
//
//  VEVENTs out of a file: the three forms of a time, DURATION, nested
//  components passed over, and edited occurrences of a series.
//

import Foundation

enum ICSReader {

    static func read(_ text: String, calendar: Calendar) throws(TimetableError) -> ICalendarImport {
        let lines = ICSLines.unfold(text).compactMap(ICSLines.parse)
        guard lines.contains(where: { $0.name == "BEGIN" && ["VCALENDAR", "VEVENT"].contains($0.value.uppercased()) }) else {
            throw .notICalendar
        }
        let name = lines.first { $0.name == "X-WR-CALNAME" }?.textValue

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
            let title = first("SUMMARY")?.textValue ?? String(localized: "Untitled", bundle: .module)
            let uid = first("UID")?.textValue ?? "event-\(index + 1)"
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
                    isAllDay: start.isDay, notes: first("DESCRIPTION")?.textValue, location: first("LOCATION")?.textValue,
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
                                          notes: first("DESCRIPTION")?.textValue, location: first("LOCATION")?.textValue,
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
