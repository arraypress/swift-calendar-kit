//
//  OpeningHoursCard.swift
//  CalendarUI
//

import SwiftUI

/// Opening hours at a glance: open or closed right now and until when, then
/// the week folded into lines, today's in bold.
public struct OpeningHoursCard: View {

    private let hours: OpeningHours
    private let calendar: Calendar
    private let title: String

    /// A card for some opening hours.
    public init(_ hours: OpeningHours, title: String = String(localized: "Opening hours"), calendar: Calendar = .current) {
        self.hours = hours
        self.calendar = calendar
        self.title = title
    }

    public var body: some View {
        TimelineView(.everyMinute) { context in
            let status = status(at: context.date)
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    HStack(spacing: 6) {
                        Circle().fill(status.open ? Color.green : Color.red).frame(width: 8, height: 8)
                        Text(status.text).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    let today = DayMathBridge.weekday(of: context.date, in: calendar)
                    ForEach(Timetable.summary(hours, calendar: calendar, closedLabel: String(localized: "Closed"))) { line in
                        let isToday = line.days.contains(today)
                        GridRow {
                            Text(line.dayLabel)
                            Text(line.hoursLabel).foregroundStyle(line.isClosed ? .secondary : .primary)
                        }
                        .font(.subheadline.weight(isToday ? .semibold : .regular))
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.08)))
        }
    }

    /// "Open · closes 17:30", or "Closed · opens Mon 09:00".
    private func status(at now: Date) -> (open: Bool, text: String) {
        let today = CalendarDay(now, in: calendar)
        let ahead = Timetable.openIntervals(hours, from: today, through: today.adding(days: 8), calendar: calendar)
        let time = { (date: Date) in calendar.format(date) { $0.hour().minute() } }
        if let current = ahead.first(where: { $0.start <= now && now < $0.end }) {
            return (true, String(localized: "Open · closes \(time(current.end))"))
        }
        if let next = ahead.first(where: { $0.start > now }) {
            let when = calendar.isDate(next.start, inSameDayAs: now)
                ? time(next.start)
                : calendar.format(next.start) { $0.weekday(.abbreviated) } + " " + time(next.start)
            return (false, String(localized: "Closed · opens \(when)"))
        }
        return (false, String(localized: "Closed"))
    }
}

/// The weekday of an instant as `Locale.Weekday`, for matching summary lines.
enum DayMathBridge {
    static func weekday(of date: Date, in calendar: Calendar) -> Locale.Weekday {
        CalendarDay(date, in: calendar).weekday
    }
}
