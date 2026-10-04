//
//  GridTests.swift
//  CalendarCore
//

import XCTest
@testable import CalendarCore

final class GridTests: XCTestCase {

    func testSeptemberFromMondayLeadsWithOneAugustDay() {
        let grid = Timetable.month(containing: at("2026-09-15"), calendar: calendar())
        XCTAssertEqual(grid.weeks.count, 5)
        XCTAssertEqual(grid.days.first?.date, at("2026-08-31"))
        XCTAssertEqual(grid.days.first?.isInMonth, false)
        XCTAssertEqual(grid.days[1].number, 1)
        XCTAssertEqual(grid.days.filter(\.isInMonth).count, 30)
    }

    func testSeptemberFromSundayLeadsWithTwoAugustDays() {
        let grid = Timetable.month(containing: at("2026-09-15"), calendar: calendar(firstWeekday: 1, locale: "en_US"))
        XCTAssertEqual(grid.days.prefix(2).map(\.number), [30, 31])
        XCTAssertEqual(grid.days[2].date, at("2026-09-01"))
    }

    func testFebruary2026FitsFourWeeksWhenTheWeekStartsSunday() {
        let sunday = Timetable.month(containing: at("2026-02-10"), calendar: calendar(firstWeekday: 1))
        let monday = Timetable.month(containing: at("2026-02-10"), calendar: calendar())
        XCTAssertEqual(sunday.weeks.count, 4)
        XCTAssertEqual(monday.weeks.count, 5)
    }

    func testAugust2026NeedsSixWeeksFromMonday() {
        XCTAssertEqual(Timetable.month(containing: at("2026-08-10"), calendar: calendar()).weeks.count, 6)
    }

    func testSixRowsIsAlwaysSix() {
        let grid = Timetable.month(containing: at("2026-02-10"), calendar: calendar(firstWeekday: 1), rows: .six)
        XCTAssertEqual(grid.weeks.count, 6)
        XCTAssertTrue(grid.weeks.allSatisfy { $0.count == 7 })
        XCTAssertEqual(grid.days.last?.date, at("2026-03-14"))
    }

    func testEveryBoxIsMidnightAcrossTheSpringClockChange() {
        let cal = calendar(london)
        let grid = Timetable.month(containing: at("2026-03-15", london), calendar: cal)
        XCTAssertTrue(grid.days.allSatisfy { cal.component(.hour, from: $0.date) == 0 })
        XCTAssertEqual(Set(grid.days.map(\.date)).count, grid.days.count)
        XCTAssertEqual(grid.days.filter(\.isInMonth).count, 31)
    }

    func testAYearIsTwelveMonths() {
        let year = Timetable.year(containing: at("2026-06-01"), calendar: calendar())
        XCTAssertEqual(year.count, 12)
        XCTAssertEqual(year.first?.month.start, at("2026-01-01"))
        XCTAssertEqual(year.last?.month.end, at("2027-01-01"))
    }

    func testTheWeekFollowsTheCalendarsFirstDay() {
        XCTAssertEqual(Timetable.week(containing: at("2026-09-03"), calendar: calendar()).first, at("2026-08-31"))
        XCTAssertEqual(Timetable.week(containing: at("2026-09-03"), calendar: calendar(firstWeekday: 1)).first, at("2026-08-30"))
        XCTAssertEqual(Timetable.week(containing: at("2026-09-03"), calendar: calendar()).count, 7)
    }

    func testAThreeDayRunCrossesAMonthEnd() {
        XCTAssertEqual(Timetable.days(from: at("2026-08-30T15:00"), count: 3, calendar: calendar()),
                       [at("2026-08-30"), at("2026-08-31"), at("2026-09-01")])
    }

    func testWeekdaySymbolsRunInTheWeeksOrder() {
        XCTAssertEqual(Timetable.weekdaySymbols(calendar: calendar(firstWeekday: 1, locale: "en_US")),
                       ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])
        XCTAssertEqual(Timetable.weekdaySymbols(calendar: calendar(), style: .full).first, "Monday")
        XCTAssertEqual(Timetable.weekdaySymbols(calendar: calendar(locale: "fr_FR"), style: .full).first, "lundi")
    }
}
