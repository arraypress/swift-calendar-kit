//
//  LayoutTests.swift
//  CalendarCore
//
//  Where timed events sit on Friday 4 September 2026, and what happens
//  either side of midnight and the clock changes.
//

import XCTest
@testable import CalendarCore

final class LayoutTests: XCTestCase {

    private func placed(_ events: [BasicEvent], minimum: TimeInterval = 0) -> [String: TimedPlacement<BasicEvent>] {
        let layout = Timetable.layout(events, on: at("2026-09-04"), calendar: calendar(), minimumDuration: minimum)
        return Dictionary(uniqueKeysWithValues: layout.timed.map { ($0.event.id, $0) })
    }

    func testTwoOverlappingEventsSitSideBySide() {
        let p = placed([event("a", "2026-09-04T09:00", "2026-09-04T11:00"), event("b", "2026-09-04T10:00", "2026-09-04T12:00")])
        XCTAssertEqual(p["a"]?.column, 0)
        XCTAssertEqual(p["b"]?.column, 1)
        XCTAssertEqual(p["a"]?.columns, 2)
        XCTAssertEqual(p["b"]?.leading, 0.5)
        XCTAssertEqual(p["b"]?.width, 0.5)
    }

    func testTouchingEventsDoNotShare() {
        let p = placed([event("a", "2026-09-04T09:00", "2026-09-04T10:00"), event("b", "2026-09-04T10:00", "2026-09-04T11:00")])
        XCTAssertEqual(p["a"]?.columns, 1)
        XCTAssertEqual(p["b"]?.columns, 1)
    }

    func testAFreedColumnIsReused() {
        let p = placed([
            event("long", "2026-09-04T09:00", "2026-09-04T12:00"),
            event("early", "2026-09-04T09:00", "2026-09-04T10:00"),
            event("later", "2026-09-04T10:00", "2026-09-04T11:00"),
        ])
        XCTAssertEqual(p["long"]?.column, 0)
        XCTAssertEqual(p["early"]?.column, 1)
        XCTAssertEqual(p["later"]?.column, 1)
        XCTAssertEqual(p["later"]?.columns, 2)
    }

    func testAnEventWidensIntoColumnsFreeForItsWholeLength() {
        let p = placed([
            event("a", "2026-09-04T09:00", "2026-09-04T12:00"),
            event("b", "2026-09-04T09:00", "2026-09-04T10:00"),
            event("c", "2026-09-04T09:00", "2026-09-04T10:00"),
            event("d", "2026-09-04T10:00", "2026-09-04T12:00"),
        ])
        XCTAssertEqual(p["d"]?.column, 1)
        XCTAssertEqual(p["d"]?.columns, 3)
        XCTAssertEqual(p["d"]?.span, 2)
        XCTAssertEqual(p["b"]?.span, 1)
        XCTAssertEqual(p["c"]?.span, 1)
    }

    func testSeparateClustersEachGetTheFullWidth() {
        let p = placed([
            event("a", "2026-09-04T09:00", "2026-09-04T10:00"), event("b", "2026-09-04T09:30", "2026-09-04T10:00"),
            event("c", "2026-09-04T14:00", "2026-09-04T15:00"),
        ])
        XCTAssertEqual(p["a"]?.columns, 2)
        XCTAssertEqual(p["c"]?.columns, 1)
        XCTAssertEqual(p["c"]?.width, 1)
    }

    func testAMinimumDurationMakesShortEventsCollide() {
        let events = [event("a", "2026-09-04T09:00", "2026-09-04T09:05"), event("b", "2026-09-04T09:10", "2026-09-04T10:00")]
        XCTAssertEqual(placed(events)["a"]?.columns, 1)
        let p = placed(events, minimum: 30 * 60)
        XCTAssertEqual(p["a"]?.columns, 2)
        XCTAssertEqual(p["a"]!.height, 0.5 / 24, accuracy: 1e-9)
    }

    func testEventsAtTheSameInstantDoNotStack() {
        let p = placed([event("a", "2026-09-04T09:00", "2026-09-04T09:00"), event("b", "2026-09-04T09:00", "2026-09-04T09:00")])
        XCTAssertEqual(p["a"]?.columns, 2)
    }

    func testPositionsAreFractionsOfTheDay() {
        let p = placed([event("a", "2026-09-04T06:00", "2026-09-04T12:00")])
        XCTAssertEqual(p["a"]?.top, 0.25)
        XCTAssertEqual(p["a"]?.height, 0.25)
    }

    func testAnOvernightEventIsCutAtMidnightOnBothDays() {
        let late = event("late", "2026-09-04T22:00", "2026-09-05T02:00")
        let friday = Timetable.layout([late], on: at("2026-09-04"), calendar: calendar()).timed[0]
        let saturday = Timetable.layout([late], on: at("2026-09-05"), calendar: calendar()).timed[0]
        XCTAssertEqual(friday.top, 22.0 / 24, accuracy: 1e-9)
        XCTAssertEqual(friday.height, 2.0 / 24, accuracy: 1e-9)
        XCTAssertTrue(friday.continuesToNextDay)
        XCTAssertFalse(friday.continuesFromPreviousDay)
        XCTAssertEqual(saturday.top, 0)
        XCTAssertEqual(saturday.end, at("2026-09-05T02:00"))
        XCTAssertTrue(saturday.continuesFromPreviousDay)
    }

    func testAllDayEndsAreExclusive() {
        let trip = event("trip", "2026-09-04", "2026-09-05", allDay: true)
        XCTAssertEqual(Timetable.layout([trip], on: at("2026-09-04"), calendar: calendar()).allDay.map(\.id), ["trip"])
        XCTAssertTrue(Timetable.layout([trip], on: at("2026-09-05"), calendar: calendar()).allDay.isEmpty)
        XCTAssertTrue(Timetable.layout([trip], on: at("2026-09-04"), calendar: calendar()).timed.isEmpty)
    }

    func testAnAllDayEventWithNoLengthCoversItsDay() {
        let birthday = event("birthday", "2026-09-04", "2026-09-04", allDay: true)
        XCTAssertEqual(Timetable.layout([birthday], on: at("2026-09-04"), calendar: calendar()).allDay.count, 1)
        XCTAssertEqual(Timetable.events([birthday], on: [at("2026-09-04"), at("2026-09-05")], calendar: calendar()).map(\.count), [1, 0])
    }

    func testTheSpringClockChangeDayIsTwentyThreeHours() {
        let cal = calendar(london)
        let lunch = event("lunch", "2026-03-29T12:00", "2026-03-29T13:00", london)
        let layout = Timetable.layout([lunch], on: at("2026-03-29", london), calendar: cal)
        XCTAssertEqual(layout.day.duration, 23 * hour)
        XCTAssertEqual(layout.timed[0].top, 11.0 / 23, accuracy: 1e-9)

        let marks = Timetable.hourMarks(on: at("2026-03-29", london), calendar: cal)
        XCTAssertEqual(marks.count, 23)
        XCTAssertEqual(marks.prefix(3).map(\.hour), [0, 2, 3])
        let noon = marks.first { $0.hour == 12 }!
        XCTAssertEqual(noon.position, layout.timed[0].top, accuracy: 1e-9)
    }

    func testTheAutumnClockChangeDayReadsOneTwice() {
        let marks = Timetable.hourMarks(on: at("2026-10-25", london), calendar: calendar(london))
        XCTAssertEqual(marks.count, 25)
        XCTAssertEqual(marks.prefix(4).map(\.hour), [0, 1, 1, 2])
        XCTAssertEqual(Timetable.hourMarks(on: at("2026-10-25", london), every: 6, calendar: calendar(london)).count, 5)
    }

    func testEventsPerDayPutAllDayFirst() {
        let events = [
            event("meeting", "2026-09-04T09:00", "2026-09-04T10:00"),
            event("trip", "2026-09-03", "2026-09-06", allDay: true),
            event("call", "2026-09-04T08:00", "2026-09-04T08:30"),
        ]
        let days = Timetable.events(events, on: [at("2026-09-03"), at("2026-09-04"), at("2026-09-06")], calendar: calendar())
        XCTAssertEqual(days.map { $0.map(\.id) }, [["trip"], ["trip", "call", "meeting"], []])
    }
}
