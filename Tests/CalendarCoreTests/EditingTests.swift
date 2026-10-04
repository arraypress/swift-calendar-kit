//
//  EditingTests.swift
//  CalendarCore
//
//  What drags mean in time, and the series edits behind "this event",
//  "this and following" and "all events". 7 September 2026 is a Monday.
//

import XCTest
@testable import CalendarCore

final class EditingTests: XCTestCase {

    private let meeting = interval("2026-09-07T09:00", "2026-09-07T10:00")

    func testADragDownSnapsToTheQuarterHour() {
        let moved = Timetable.moved(meeting, by: 37 * 60, calendar: calendar())
        XCTAssertEqual(moved, interval("2026-09-07T09:30", "2026-09-07T10:30"))  // 09:37 is nearer 09:30
        XCTAssertEqual(Timetable.moved(meeting, by: 38 * 60, calendar: calendar()), interval("2026-09-07T09:45", "2026-09-07T10:45"))
        XCTAssertEqual(Timetable.moved(meeting, by: 7 * 60, calendar: calendar()), meeting)
    }

    func testADragAcrossColumnsMovesWholeDaysAndKeepsTheLength() {
        XCTAssertEqual(Timetable.moved(meeting, days: 2, by: -hour, calendar: calendar()),
                       interval("2026-09-09T08:00", "2026-09-09T09:00"))
    }

    func testNineOClockDraggedAcrossTheClockChangeIsStillNine() {
        let friday = interval("2026-10-23T09:00", "2026-10-23T10:00", london)
        XCTAssertEqual(Timetable.moved(friday, days: 3, calendar: calendar(london)),
                       interval("2026-10-26T09:00", "2026-10-26T10:00", london))
    }

    func testAllDayBarsMoveByCalendarDays() {
        let stay = interval("2026-09-04", "2026-09-07")
        XCTAssertEqual(Timetable.moved(stay, byDays: -2, calendar: calendar()), interval("2026-09-02", "2026-09-05"))
    }

    func testResizingSnapsAndNeverCollapses() {
        XCTAssertEqual(Timetable.resized(meeting, end: at("2026-09-07T11:08"), calendar: calendar()),
                       interval("2026-09-07T09:00", "2026-09-07T11:15"))
        XCTAssertEqual(Timetable.resized(meeting, end: at("2026-09-07T08:00"), calendar: calendar()),
                       interval("2026-09-07T09:00", "2026-09-07T09:15"))
        XCTAssertEqual(Timetable.resized(meeting, end: at("2026-09-07T08:00"), minimum: 30 * 60, calendar: calendar()).duration, 30 * 60)
    }

    func testASweepWorksInEitherDirection() {
        XCTAssertEqual(Timetable.span(from: at("2026-09-07T14:10"), to: at("2026-09-07T12:52"), calendar: calendar()),
                       interval("2026-09-07T12:45", "2026-09-07T14:15"))  // 12:52 is nearer 12:45
        XCTAssertEqual(Timetable.span(from: at("2026-09-07T14:00"), to: at("2026-09-07T14:02"), calendar: calendar()).duration, 15 * 60)
    }

    // MARK: - Series edits

    private func starts(_ rule: RecurrenceRule, from first: String = "2026-09-07T09:00") -> [Date] {
        Timetable.occurrences(of: rule, start: at(first), end: at(first).addingTimeInterval(hour),
                              in: interval("2026-09-01", "2026-10-01"), calendar: calendar()).map(\.start)
    }

    private let daily = try! RecurrenceRule(parsing: "FREQ=DAILY;COUNT=5")

    func testSkippingRemovesOneOccurrence() {
        XCTAssertEqual(starts(daily.skipping(at("2026-09-09T09:00"))),
                       ["2026-09-07T09:00", "2026-09-08T09:00", "2026-09-10T09:00", "2026-09-11T09:00"].map { at($0) })
    }

    func testEndingBeforeKeepsEverythingEarlier() {
        XCTAssertEqual(starts(daily.ending(before: at("2026-09-09T09:00"))), ["2026-09-07T09:00", "2026-09-08T09:00"].map { at($0) })
        XCTAssertNil(daily.ending(before: at("2026-09-09T09:00")).count)
    }

    func testAFollowingSeriesDoesNotInheritTheCount() {
        XCTAssertNil(daily.unending.count)
        XCTAssertNil(daily.unending.until)
        XCTAssertEqual(starts(daily.unending).count, 24)
    }

    func testEditsKeepTheRestOfTheRule() {
        let rule = try! RecurrenceRule(parsing: "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE")
        let edited = rule.skipping(at("2026-09-09T09:00"))
        XCTAssertEqual(edited.byDay, rule.byDay)
        XCTAssertEqual(edited.interval, 2)
        XCTAssertEqual(edited.exceptions.count, 1)
    }
}
