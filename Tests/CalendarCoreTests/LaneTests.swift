//
//  LaneTests.swift
//  CalendarCore
//
//  Bars across the week of Monday 31 August to Sunday 6 September 2026.
//

import XCTest
@testable import CalendarCore

final class LaneTests: XCTestCase {

    private let week = Timetable.week(containing: at("2026-09-02"), calendar: calendar())

    private func bars(_ events: [BasicEvent], maximumLanes: Int? = nil) -> (LaneLayout<BasicEvent>, [String: LaneBar<BasicEvent>]) {
        let layout = Timetable.lanes(events, across: week, calendar: calendar(), maximumLanes: maximumLanes)
        return (layout, Dictionary(uniqueKeysWithValues: layout.bars.map { ($0.event.id, $0) }))
    }

    func testABarCoversTheDaysItTouches() {
        let (_, b) = bars([event("trip", "2026-09-02", "2026-09-06", allDay: true)])
        XCTAssertEqual(b["trip"]?.firstDay, 2)
        XCTAssertEqual(b["trip"]?.lastDay, 5)
        XCTAssertEqual(b["trip"]?.length, 4)
        XCTAssertEqual(b["trip"]?.continuesBefore, false)
        XCTAssertEqual(b["trip"]?.continuesAfter, false)
    }

    func testABarFromLastWeekIsCutAtTheRowStart() {
        let (_, b) = bars([event("holiday", "2026-08-29", "2026-09-02", allDay: true),
                           event("move", "2026-09-05", "2026-09-09", allDay: true)])
        XCTAssertEqual(b["holiday"]?.firstDay, 0)
        XCTAssertEqual(b["holiday"]?.lastDay, 1)
        XCTAssertEqual(b["holiday"]?.continuesBefore, true)
        XCTAssertEqual(b["move"]?.lastDay, 6)
        XCTAssertEqual(b["move"]?.continuesAfter, true)
    }

    func testBarsStackOnlyWhereTheyOverlap() {
        let (layout, b) = bars([
            event("holiday", "2026-08-29", "2026-09-02", allDay: true),
            event("dentist", "2026-09-01", "2026-09-02", allDay: true),
            event("trip", "2026-09-02", "2026-09-06", allDay: true),
            event("party", "2026-09-02", "2026-09-03", allDay: true),
        ])
        XCTAssertEqual(b["holiday"]?.lane, 0)
        XCTAssertEqual(b["dentist"]?.lane, 1)
        XCTAssertEqual(b["trip"]?.lane, 0)
        XCTAssertEqual(b["party"]?.lane, 1)
        XCTAssertEqual(layout.laneCount, 2)
    }

    func testTheLongerBarTakesTheTopLaneWhateverTheInputOrder() {
        let (_, b) = bars([event("party", "2026-09-02", "2026-09-03", allDay: true),
                           event("trip", "2026-09-02", "2026-09-06", allDay: true)])
        XCTAssertEqual(b["trip"]?.lane, 0)
        XCTAssertEqual(b["party"]?.lane, 1)
    }

    func testBarsOverTheLimitAreCountedPerDay() {
        let (layout, _) = bars([
            event("trip", "2026-09-02", "2026-09-06", allDay: true),
            event("party", "2026-09-02", "2026-09-03", allDay: true),
            event("gig", "2026-09-04", "2026-09-06", allDay: true),
        ], maximumLanes: 1)
        XCTAssertEqual(layout.bars.map(\.event.id), ["trip"])
        XCTAssertEqual(layout.hidden, [0, 0, 1, 0, 1, 1, 0])
    }

    func testEventsOutsideTheRowAreLeftOut() {
        let (layout, _) = bars([event("later", "2026-09-10", "2026-09-11", allDay: true)])
        XCTAssertTrue(layout.bars.isEmpty)
        XCTAssertEqual(layout.laneCount, 0)
    }

    func testTimedEventsCanBeBarsInAMonthRow() {
        let (_, b) = bars([event("flight", "2026-09-03T22:00", "2026-09-04T06:00")])
        XCTAssertEqual(b["flight"]?.firstDay, 3)
        XCTAssertEqual(b["flight"]?.lastDay, 4)
    }
}
