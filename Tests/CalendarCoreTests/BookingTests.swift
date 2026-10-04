//
//  BookingTests.swift
//  CalendarCore
//
//  Free time, slots, clashes and resources on Friday 4 September 2026, UTC.
//

import XCTest
@testable import CalendarCore

final class BookingTests: XCTestCase {

    private let workday = [interval("2026-09-04T09:00", "2026-09-04T17:00")]
    private let meetings = [interval("2026-09-04T10:00", "2026-09-04T11:00"), interval("2026-09-04T13:00", "2026-09-04T14:00")]

    func testGapsBetweenMeetings() {
        XCTAssertEqual(Timetable.freeTime(in: workday, busy: meetings), [
            interval("2026-09-04T09:00", "2026-09-04T10:00"),
            interval("2026-09-04T11:00", "2026-09-04T13:00"),
            interval("2026-09-04T14:00", "2026-09-04T17:00"),
        ])
    }

    func testABufferShrinksEveryGap() {
        XCTAssertEqual(Timetable.freeTime(in: workday, busy: meetings, buffer: 15 * 60), [
            interval("2026-09-04T09:00", "2026-09-04T09:45"),
            interval("2026-09-04T11:15", "2026-09-04T12:45"),
            interval("2026-09-04T14:15", "2026-09-04T17:00"),
        ])
    }

    func testShortGapsAreDropped() {
        XCTAssertEqual(Timetable.freeTime(in: workday, busy: meetings, minimumLength: 2 * hour).count, 2)
    }

    func testOverlappingAndOutsideBusyTimeIsHandled() {
        let busy = [
            interval("2026-09-04T08:00", "2026-09-04T09:30"),
            interval("2026-09-04T12:00", "2026-09-04T15:00"),
            interval("2026-09-04T14:00", "2026-09-04T16:00"),
            interval("2026-09-04T18:00", "2026-09-04T19:00"),
        ]
        XCTAssertEqual(Timetable.freeTime(in: workday, busy: busy), [
            interval("2026-09-04T09:30", "2026-09-04T12:00"),
            interval("2026-09-04T16:00", "2026-09-04T17:00"),
        ])
    }

    func testAFullyBookedDayHasNoGaps() {
        XCTAssertTrue(Timetable.freeTime(in: workday, busy: [interval("2026-09-04T08:00", "2026-09-04T18:00")]).isEmpty)
    }

    func testHalfHourSlotsEveryQuarterSkipTheBookedOne() {
        let slots = Timetable.slots(length: 30 * 60, every: 15 * 60, in: [interval("2026-09-04T09:00", "2026-09-04T12:00")],
                                    busy: [interval("2026-09-04T10:00", "2026-09-04T10:30")])
        let formatter = DateFormatter()
        formatter.timeZone = utc
        formatter.dateFormat = "HH:mm"
        XCTAssertEqual(slots.map { formatter.string(from: $0.start) },
                       ["09:00", "09:15", "09:30", "10:30", "10:45", "11:00", "11:15", "11:30"])
    }

    func testSlotsDefaultToBackToBack() {
        XCTAssertEqual(Timetable.slots(length: hour, in: workday, busy: meetings).count, 6)
    }

    func testTouchingIsNotAClashButABufferMakesItOne() {
        let candidate = interval("2026-09-04T11:00", "2026-09-04T12:00")
        XCTAssertTrue(Timetable.clashes(candidate, with: meetings).isEmpty)
        XCTAssertEqual(Timetable.clashes(candidate, with: meetings, buffer: 60), [0])
        XCTAssertEqual(Timetable.clashes(interval("2026-09-04T10:30", "2026-09-04T13:30"), with: meetings), [0, 1])
    }

    private let windows = [
        "alice": [interval("2026-09-04T09:00", "2026-09-04T12:00")],
        "bob": [interval("2026-09-04T10:00", "2026-09-04T13:00")],
    ]
    private let busy = ["bob": [interval("2026-09-04T10:00", "2026-09-04T11:00")]]

    func testEachSlotNamesWhoIsFree() {
        let slots = Timetable.slots(length: hour, resources: ["alice", "bob"], windows: windows, busy: busy)
        XCTAssertEqual(slots.map(\.free), [["alice"], ["alice"], ["alice", "bob"], ["bob"]])
        XCTAssertEqual(slots.map(\.interval.start), [at("2026-09-04T09:00"), at("2026-09-04T10:00"), at("2026-09-04T11:00"), at("2026-09-04T12:00")])
    }

    func testAGroupBookingNeedsEnoughResourcesFree() {
        let slots = Timetable.slots(length: hour, resources: ["alice", "bob"], windows: windows, busy: busy, minimumFree: 2)
        XCTAssertEqual(slots.map(\.interval), [interval("2026-09-04T11:00", "2026-09-04T12:00")])
    }

    func testFreeResourcesForAGivenTime() {
        XCTAssertEqual(Timetable.freeResources(for: interval("2026-09-04T11:00", "2026-09-04T12:00"),
                                               resources: ["alice", "bob", "carol"], windows: windows, busy: busy), ["alice", "bob"])
        XCTAssertEqual(Timetable.freeResources(for: interval("2026-09-04T10:30", "2026-09-04T11:30"),
                                               resources: ["alice", "bob"], windows: windows, busy: busy), ["alice"])
        XCTAssertEqual(Timetable.freeResources(for: interval("2026-09-04T11:30", "2026-09-04T12:30"),
                                               resources: ["alice", "bob"], windows: windows, busy: busy), ["bob"])
    }

    // MARK: - Conflicts

    private let diary = [
        event("a", "2026-09-04T09:00", "2026-09-04T10:00"),
        event("b", "2026-09-04T09:30", "2026-09-04T10:30"),
        event("c", "2026-09-04T10:35", "2026-09-04T11:00"),
        event("d", "2026-09-04T13:00", "2026-09-04T14:00"),
        event("e", "2026-09-04T14:00", "2026-09-04T15:00"),
        event("trip", "2026-09-04", "2026-09-05", allDay: true),
    ]

    func testOverlapsConflict() {
        XCTAssertEqual(Timetable.conflicts(diary), ["a", "b"])
    }

    func testABufferCatchesEventsTooCloseTogether() {
        XCTAssertEqual(Timetable.conflicts(diary, buffer: 10 * 60), ["a", "b", "c", "d", "e"])
        XCTAssertEqual(Timetable.conflicts(diary, buffer: 4 * 60), ["a", "b", "d", "e"])
    }

    func testOnlyEventsInTheSameGroupCompete() {
        let rooms = ["a": 1, "b": 2, "c": 2, "d": 1, "e": 2]
        let found = Timetable.conflicts(diary, buffer: 10 * 60) { rooms[$0.id] == rooms[$1.id] }
        XCTAssertEqual(found, ["b", "c"])
    }

    func testALongEventConflictsWithEverythingInside() {
        let found = Timetable.conflicts([
            event("day", "2026-09-04T08:00", "2026-09-04T18:00"),
            event("x", "2026-09-04T09:00", "2026-09-04T09:30"),
            event("y", "2026-09-04T16:00", "2026-09-04T16:30"),
        ])
        XCTAssertEqual(found, ["day", "x", "y"])
    }
}
