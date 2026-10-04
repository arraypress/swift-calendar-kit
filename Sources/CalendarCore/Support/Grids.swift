//
//  Grids.swift
//  CalendarCore
//
//  Month, week and year shapes in whatever calendar the caller hands over —
//  its first weekday, its months, its zone.
//

import Foundation

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
