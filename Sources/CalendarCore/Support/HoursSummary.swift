//
//  HoursSummary.swift
//  CalendarCore
//
//  A weekly pattern folded into lines, the way a shop door or Maps shows it:
//  neighbouring days with the same hours share a line.
//

import Foundation

extension Timetable {

    /// Opening hours as week-at-a-glance lines, in the calendar's week order
    /// and its locale's clock.
    ///
    /// - Parameter closedLabel: what a closed day reads; "Closed" in the
    ///   reader's language unless given.
    public static func summary(_ hours: OpeningHours, calendar: Calendar = .current, closedLabel: String? = nil) -> [HoursLine] {
        HoursSummary.lines(hours, in: calendar, closedLabel: closedLabel ?? String(localized: "Closed", bundle: .module))
    }
}

enum HoursSummary {

    static func lines(_ hours: OpeningHours, in calendar: Calendar, closedLabel: String) -> [HoursLine] {
        let order = (0..<7).map { DayMath.weekday(foundation: (calendar.firstWeekday - 1 + $0) % 7 + 1) }
        var groups: [(days: [Locale.Weekday], windows: [TimeWindow])] = []
        for day in order {
            let windows = (hours.weekly[day] ?? []).sorted { $0.opens < $1.opens }
            if let last = groups.last, last.windows == windows {
                groups[groups.count - 1].days.append(day)
            } else {
                groups.append(([day], windows))
            }
        }

        let symbols = calendar.shortStandaloneWeekdaySymbols
        let name = { (day: Locale.Weekday) in symbols[DayMath.foundationNumber(of: day) - 1] }
        let formatter = clockFormatter(for: calendar.locale ?? .current)

        return groups.map { group in
            let dayLabel: String
            switch group.days.count {
            case 1: dayLabel = name(group.days[0])
            case 2: dayLabel = "\(name(group.days[0])), \(name(group.days[1]))"
            default: dayLabel = "\(name(group.days[0]))–\(name(group.days.last!))"
            }
            let hoursLabel = group.windows.isEmpty ? closedLabel : group.windows.map { window in
                "\(clock(window.opens, formatter))–\(clock(window.closes, formatter))"
            }.joined(separator: ", ")
            return HoursLine(days: group.days, windows: group.windows, dayLabel: dayLabel, hoursLabel: hoursLabel)
        }
    }

    /// Hours and minutes in the locale's own clock, 12- or 24-hour.
    static func clockFormatter(for locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        return formatter
    }

    /// 24:00 reads as the midnight it is.
    static func clock(_ time: DayTime, _ formatter: DateFormatter) -> String {
        let minutes = time.minutesIntoDay % (24 * 60)
        return formatter.string(from: Date(timeIntervalSinceReferenceDate: TimeInterval(minutes * 60)))
    }
}
