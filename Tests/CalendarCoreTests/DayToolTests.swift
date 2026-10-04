//
//  DayToolTests.swift
//  CalendarCore
//
//  Week numbers down a month, progress through a day that may end past
//  midnight, and one copy of an event that two calendars both hold.
//

import XCTest
@testable import CalendarCore

final class DayToolTests: XCTestCase {

    // MARK: - Week numbers

    func testJanuary2027StartsInISOWeek53() {
        // 1 January 2027 is a Friday, in ISO week 53 of 2026.
        let grid = Timetable.month(containing: at("2027-01-15"), calendar: calendar())
        XCTAssertEqual(Timetable.weekNumbers(of: grid, numbering: .iso8601, calendar: calendar()), [53, 1, 2, 3, 4])
    }

    func testRegionalNumberingFollowsTheCalendar() {
        // America: weeks from Sunday, week 1 holds 1 January — so January 2027 starts in week 1.
        let american = calendar(firstWeekday: 1, locale: "en_US")
        var us = american
        us.minimumDaysInFirstWeek = 1
        let grid = Timetable.month(containing: at("2027-01-15"), calendar: us)
        XCTAssertEqual(Timetable.weekNumbers(of: grid, numbering: .regional, calendar: us).first, 1)
        XCTAssertEqual(Timetable.weekNumbers(of: grid, numbering: .iso8601, calendar: us).first, 53)
    }

    func testISONumbersOfASundayFirstRowFollowItsMonday() {
        let grid = Timetable.month(containing: at("2026-09-15"), calendar: calendar(firstWeekday: 1, locale: "en_US"))
        // The first row runs Sunday 30 August to Saturday 5 September; its Monday is 31 August, ISO week 36.
        XCTAssertEqual(Timetable.weekNumbers(of: grid, numbering: .iso8601, calendar: calendar()).first, 36)
    }

    // MARK: - Progress

    private let workday = try! DayRange("09:00", "17:00")
    private let lateDay = try! DayRange("08:00", "02:00")

    func testHalfWayThroughTheWorkingDay() throws {
        let p = try XCTUnwrap(Timetable.progress(at: at("2026-09-04T13:00"), through: [workday], calendar: calendar()))
        XCTAssertEqual(p.fraction, 0.5)
        XCTAssertEqual(p.remaining, 4 * hour)
        XCTAssertEqual(p.interval, interval("2026-09-04T09:00", "2026-09-04T17:00"))
    }

    func testADayEndingPastMidnightIsStillRunningAtOne() throws {
        let p = try XCTUnwrap(Timetable.progress(at: at("2026-09-05T01:00"), through: [lateDay], calendar: calendar()))
        XCTAssertEqual(p.interval, interval("2026-09-04T08:00", "2026-09-05T02:00"))
        XCTAssertEqual(p.remaining, hour)
        XCTAssertEqual(p.fraction, 17.0 / 18, accuracy: 1e-9)
    }

    func testBetweenRangesThereIsNoProgress() {
        XCTAssertNil(Timetable.progress(at: at("2026-09-04T18:00"), through: [workday], calendar: calendar()))
        XCTAssertNil(Timetable.progress(at: at("2026-09-05T03:00"), through: [lateDay], calendar: calendar()))
    }

    func testConsecutiveRangesHandOver() throws {
        let ranges = [try DayRange("09:00", "12:00"), try DayRange("12:00", "18:00")]
        XCTAssertEqual(Timetable.progress(at: at("2026-09-04T11:59"), through: ranges, calendar: calendar())?.index, 0)
        XCTAssertEqual(Timetable.progress(at: at("2026-09-04T12:00"), through: ranges, calendar: calendar())?.index, 1)
    }

    func testAWholeDayAcrossTheSpringClockChangeIsTwentyThreeHours() throws {
        let p = try XCTUnwrap(Timetable.progress(at: at("2026-03-29T12:00", london), through: [try DayRange("00:00", "24:00")],
                                                 calendar: calendar(london)))
        XCTAssertEqual(p.interval.duration, 23 * hour)
        XCTAssertEqual(p.elapsed, 11 * hour)
    }

    func testFridaysLateNightBelongsToFriday() throws {
        let weekly: [Locale.Weekday: [DayRange]] = [.friday: [try DayRange("18:00", "03:00")], .saturday: [try DayRange("10:00", "16:00")]]
        let early = try XCTUnwrap(Timetable.progress(at: at("2026-09-05T02:00"), through: weekly, calendar: calendar()))
        XCTAssertEqual(early.interval.start, at("2026-09-04T18:00"))
        XCTAssertEqual(Timetable.progress(at: at("2026-09-05T12:00"), through: weekly, calendar: calendar())?.interval.start,
                       at("2026-09-05T10:00"))
    }

    // MARK: - Duplicates

    func testAnEventInTwoCalendarsIsKeptOnce() {
        let events = [
            BasicEvent(id: "work", title: "Standup", start: at("2026-09-04T09:00"), end: at("2026-09-04T10:00")),
            BasicEvent(id: "home", title: "  standup ", start: at("2026-09-04T09:00"), end: at("2026-09-04T10:00")),
            BasicEvent(id: "other", title: "Standup", start: at("2026-09-04T09:00"), end: at("2026-09-04T09:30")),
        ]
        XCTAssertEqual(Timetable.deduplicated(events, title: \.title).map(\.id), ["work", "other"])
    }

    func testAnAllDayAndATimedEventAreNotTheSame() {
        let a = BasicEvent(id: "a", title: "Trip", start: at("2026-09-04"), end: at("2026-09-05"), isAllDay: true)
        let b = BasicEvent(id: "b", title: "Trip", start: at("2026-09-04"), end: at("2026-09-05"))
        XCTAssertEqual(Timetable.deduplicated([a, b], title: \.title).count, 2)
    }
}
