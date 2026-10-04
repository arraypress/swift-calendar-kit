//
//  CalendarDayTests.swift
//  CalendarCore
//

import XCTest
@testable import CalendarCore

final class CalendarDayTests: XCTestCase {

    func testOnlyRealDaysExist() throws {
        XCTAssertThrowsError(try CalendarDay(year: 2026, month: 2, day: 29))
        XCTAssertNoThrow(try CalendarDay(year: 2028, month: 2, day: 29))
        XCTAssertThrowsError(try CalendarDay(year: 2026, month: 13, day: 1))
        XCTAssertThrowsError(try CalendarDay(year: 2026, month: 4, day: 31))
        XCTAssertThrowsError(try CalendarDay(year: 2026, month: 4, day: 0))
    }

    func testCountingDaysAcrossAYearEnd() {
        XCTAssertEqual(day("2026-12-30").adding(days: 3), day("2027-01-02"))
        XCTAssertEqual(day("2026-03-01").adding(days: -1), day("2026-02-28"))
        XCTAssertEqual(day("2026-01-01").days(until: day("2027-01-01")), 365)
        XCTAssertEqual(day("2026-03-28").days(until: day("2026-03-30")), 2)
    }

    func testWeekdays() {
        XCTAssertEqual(day("2026-09-04").weekday, .friday)
        XCTAssertEqual(day("2026-08-30").weekday, .sunday)
    }

    func testTheZoneDecidesWhichDayAnInstantIs() {
        let instant = at("2026-09-04T23:30")
        XCTAssertEqual(CalendarDay(instant, in: calendar()), day("2026-09-04"))
        XCTAssertEqual(CalendarDay(instant, in: calendar(auckland)), day("2026-09-05"))
    }

    func testADayStartsAtLocalMidnight() {
        XCTAssertEqual(day("2026-09-04").date(in: calendar(london)), at("2026-09-03T23:00"))
        XCTAssertEqual(day("2026-09-04").description, "2026-09-04")
    }

    func testDaysSortAndEncode() throws {
        XCTAssertLessThan(day("2026-09-04"), day("2026-10-01"))
        XCTAssertLessThan(day("2025-12-31"), day("2026-01-01"))
        let data = try JSONEncoder().encode(day("2026-09-04"))
        XCTAssertEqual(try JSONDecoder().decode(CalendarDay.self, from: data), day("2026-09-04"))
    }
}
