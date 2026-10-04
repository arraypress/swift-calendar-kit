//
//  Grids.swift
//  CalendarCore
//
//  Month, week and year shapes in whatever calendar the caller hands over —
//  its first weekday, its months, its zone.
//

import Foundation

extension Timetable {

    /// The month containing a date, as rows of whole weeks.
    public static func month(containing date: Date, calendar: Calendar = .current, rows: GridRows = .fitted) -> MonthGrid {
        Grids.month(containing: date, in: calendar, rows: rows)
    }

    /// Every month of the year containing a date.
    public static func year(containing date: Date, calendar: Calendar = .current, rows: GridRows = .fitted) -> [MonthGrid] {
        Grids.year(containing: date, in: calendar, rows: rows)
    }

    /// The seven days of the week containing a date, from the calendar's first weekday.
    public static func week(containing date: Date, calendar: Calendar = .current) -> [Date] {
        Grids.week(containing: date, in: calendar)
    }

    /// `count` consecutive days from a date's day — a three-day view, say.
    public static func days(from date: Date, count: Int, calendar: Calendar = .current) -> [Date] {
        Grids.days(from: date, count: count, in: calendar)
    }

    /// The number of each week of a month grid, top row first.
    public static func weekNumbers(of grid: MonthGrid, numbering: WeekNumbering = .regional,
                                   calendar: Calendar = .current) -> [Int] {
        Grids.weekNumbers(of: grid, numbering: numbering, in: calendar)
    }

    /// Weekday names in the order the calendar's week runs, in its locale.
    public static func weekdaySymbols(calendar: Calendar = .current, style: WeekdayStyle = .short) -> [String] {
        Grids.weekdaySymbols(in: calendar, style: style)
    }
}

enum Grids {

    static func month(containing date: Date, in calendar: Calendar, rows: GridRows) -> MonthGrid {
        let month = calendar.dateInterval(of: .month, for: date)!
        let first = month.start
        let leading = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let length = calendar.range(of: .day, in: .month, for: first)!.count
        let weekCount = rows == .six ? 6 : (leading + length + 6) / 7
        let gridStart = calendar.date(byAdding: .day, value: -leading, to: first)!

        let days = (0..<weekCount * 7).map { offset -> GridDay in
            let day = calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: gridStart)!)
            return GridDay(date: day, number: calendar.component(.day, from: day), isInMonth: month.contains(day) && day < month.end)
        }
        let weeks = stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<$0 + 7]) }
        return MonthGrid(month: month, weeks: weeks)
    }

    static func year(containing date: Date, in calendar: Calendar, rows: GridRows) -> [MonthGrid] {
        let year = calendar.dateInterval(of: .year, for: date)!
        let count = calendar.range(of: .month, in: .year, for: year.start)!.count
        return (0..<count).map { offset in
            month(containing: calendar.date(byAdding: .month, value: offset, to: year.start)!, in: calendar, rows: rows)
        }
    }

    static func week(containing date: Date, in calendar: Calendar) -> [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)!.start
        return days(from: start, count: 7, in: calendar)
    }

    static func days(from date: Date, count: Int, in calendar: Calendar) -> [Date] {
        let first = calendar.startOfDay(for: date)
        return (0..<max(count, 0)).map { calendar.startOfDay(for: calendar.date(byAdding: .day, value: $0, to: first)!) }
    }

    static func weekNumbers(of grid: MonthGrid, numbering: WeekNumbering, in calendar: Calendar) -> [Int] {
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = calendar.timeZone
        return grid.weeks.map { week in
            switch numbering {
            case .regional:
                return calendar.component(.weekOfYear, from: week[0].date)
            case .iso8601:
                let monday = week.first { iso.component(.weekday, from: $0.date) == 2 } ?? week[0]
                return iso.component(.weekOfYear, from: monday.date)
            }
        }
    }

    static func weekdaySymbols(in calendar: Calendar, style: WeekdayStyle) -> [String] {
        let symbols: [String]
        switch style {
        case .narrow: symbols = calendar.veryShortStandaloneWeekdaySymbols
        case .short: symbols = calendar.shortStandaloneWeekdaySymbols
        case .full: symbols = calendar.standaloneWeekdaySymbols
        }
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }
}
