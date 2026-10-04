//
//  ListingTests.swift
//  CalendarCore
//
//  The list view and the bookings board, around Friday 4 September 2026, UTC.
//

import XCTest
@testable import CalendarCore

final class ListingTests: XCTestCase {

    private let days = Timetable.days(from: at("2026-09-03"), count: 4, calendar: calendar())

    func testTheListSkipsEmptyDaysUnlessAsked() {
        let events = [event("dentist", "2026-09-04T09:00", "2026-09-04T10:00")]
        XCTAssertEqual(Timetable.agenda(events, on: days, calendar: calendar()).map(\.day.start), [at("2026-09-04")])
        XCTAssertEqual(Timetable.agenda(events, on: days, calendar: calendar(), includeEmptyDays: true).count, 4)
    }

    func testAnOvernightEventIsListedOnBothDaysCutToEach() {
        let flight = event("flight", "2026-09-04T22:00", "2026-09-05T06:00")
        let list = Timetable.agenda([flight], on: days, calendar: calendar())
        XCTAssertEqual(list.count, 2)
        let friday = list[0].entries[0], saturday = list[1].entries[0]
        XCTAssertEqual(friday.start, at("2026-09-04T22:00"))
        XCTAssertEqual(friday.end, at("2026-09-05"))
        XCTAssertTrue(friday.continuesToNextDay)
        XCTAssertEqual(saturday.start, at("2026-09-05"))
        XCTAssertEqual(saturday.end, at("2026-09-05T06:00"))
        XCTAssertTrue(saturday.continuesFromPreviousDay)
        XCTAssertFalse(saturday.isAllDay)
    }

    func testAMiddleDayOfALongTimedEventReadsAllDay() {
        let conference = event("conference", "2026-09-03T09:00", "2026-09-05T17:00")
        let list = Timetable.agenda([conference], on: days, calendar: calendar())
        XCTAssertEqual(list.map { $0.entries[0].isAllDay }, [false, true, false])
    }

    func testAStayCountsItsDays() {
        let stay = event("stay", "2026-09-02", "2026-09-06", allDay: true)
        let list = Timetable.agenda([stay], on: days, calendar: calendar())
        XCTAssertEqual(list.map { $0.entries[0].dayOfEvent }, [2, 3, 4])
        XCTAssertEqual(list.map { $0.entries[0].eventDayCount }, [4, 4, 4])
    }

    func testAnEventEndingAtMidnightDoesNotCountTheNextDay() {
        let late = event("late", "2026-09-04T20:00", "2026-09-05T00:00")
        let entry = Timetable.agenda([late], on: days, calendar: calendar())[0].entries[0]
        XCTAssertEqual(entry.eventDayCount, 1)
        XCTAssertEqual(entry.dayOfEvent, 1)
    }

    func testAllDayComesFirstThenByStart() {
        let list = Timetable.agenda([
            event("lunch", "2026-09-04T12:00", "2026-09-04T13:00"),
            event("holiday", "2026-09-04", "2026-09-05", allDay: true),
            event("standup", "2026-09-04T09:00", "2026-09-04T09:15"),
        ], on: days, calendar: calendar())
        XCTAssertEqual(list[0].entries.map(\.event.id), ["holiday", "standup", "lunch"])
    }

    // MARK: - Board

    private let week = Timetable.days(from: at("2026-09-01"), count: 7, calendar: calendar())

    private func stay(_ id: String, _ room: String, _ from: String, _ to: String) -> BasicEvent {
        BasicEvent(id: id, title: room, start: at(from), end: at(to), isAllDay: true)
    }

    func testEachResourceGetsARowInTheOrderGiven() {
        let rows = Timetable.board([stay("a", "Flat 3", "2026-09-02", "2026-09-04")],
                                   resources: ["Cottage", "Flat 3"], resourceOf: \.title, across: week, calendar: calendar())
        XCTAssertEqual(rows.map(\.resource), ["Cottage", "Flat 3"])
        XCTAssertTrue(rows[0].lanes.bars.isEmpty)
        XCTAssertEqual(rows[1].lanes.bars.map(\.firstDay), [1])
        XCTAssertEqual(rows[1].lanes.bars.map(\.lastDay), [2])
    }

    func testFreeDaysAreTheUnbookedOnes() {
        let rows = Timetable.board([stay("a", "Flat 3", "2026-09-02", "2026-09-04")],
                                   resources: ["Flat 3"], resourceOf: \.title, across: week, calendar: calendar())
        XCTAssertEqual(rows[0].isFree, [true, false, false, true, true, true, true])
        XCTAssertEqual(rows[0].occupancy, 2.0 / 7, accuracy: 1e-9)
    }

    func testBackToBackStaysShareALaneAndDoNotClash() {
        let rows = Timetable.board([stay("a", "Flat 3", "2026-09-01", "2026-09-04"), stay("b", "Flat 3", "2026-09-04", "2026-09-06")],
                                   resources: ["Flat 3"], resourceOf: \.title, across: week, calendar: calendar())
        XCTAssertEqual(rows[0].lanes.laneCount, 1)
        XCTAssertTrue(rows[0].clashingDays.isEmpty)
    }

    func testADoubleBookingStacksAndIsFlagged() {
        let rows = Timetable.board([stay("a", "Flat 3", "2026-09-01", "2026-09-04"), stay("b", "Flat 3", "2026-09-03", "2026-09-06")],
                                   resources: ["Flat 3"], resourceOf: \.title, across: week, calendar: calendar())
        XCTAssertEqual(rows[0].lanes.laneCount, 2)
        XCTAssertEqual(rows[0].clashingDays, [2])  // only the night of the 3rd is held twice
    }

    func testBookingsForUnlistedResourcesAreLeftOff() {
        let rows = Timetable.board([stay("a", "Somewhere else", "2026-09-02", "2026-09-04")],
                                   resources: ["Flat 3"], resourceOf: \.title, across: week, calendar: calendar())
        XCTAssertTrue(rows[0].lanes.bars.isEmpty)
    }
}
