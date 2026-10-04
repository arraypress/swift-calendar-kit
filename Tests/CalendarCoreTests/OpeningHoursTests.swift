//
//  OpeningHoursTests.swift
//  CalendarCore
//

import XCTest
@testable import CalendarCore

final class OpeningHoursTests: XCTestCase {

    private func hours() throws -> OpeningHours {
        var hours = OpeningHours([try TimeWindow("09:00", "12:30"), try TimeWindow("13:30", "17:00")], on: OpeningHours.weekdays)
        hours.weekly[.saturday] = [try TimeWindow("10:00", "14:00")]
        hours.exceptions[day("2026-12-25")] = []
        hours.exceptions[day("2026-12-24")] = [try TimeWindow("09:00", "13:00")]
        return hours
    }

    func testAWeekendOfIntervalsInLondon() throws {
        let open = Timetable.openIntervals(try hours(), from: day("2026-09-04"), through: day("2026-09-06"), calendar: calendar(london))
        XCTAssertEqual(open, [
            interval("2026-09-04T09:00", "2026-09-04T12:30", london),
            interval("2026-09-04T13:30", "2026-09-04T17:00", london),
            interval("2026-09-05T10:00", "2026-09-05T14:00", london),
        ])
        XCTAssertEqual(open[0].start, at("2026-09-04T08:00"))
    }

    func testExceptionsReplaceTheWeek() throws {
        let hours = try hours()
        XCTAssertFalse(hours.isOpen(on: day("2026-12-25")))
        XCTAssertEqual(hours.windows(on: day("2026-12-24")), [try TimeWindow("09:00", "13:00")])
        XCTAssertEqual(hours.windows(on: day("2026-12-23")).count, 2)
    }

    func testMidnightCloseIsTheNextDaysStart() throws {
        let late = OpeningHours([try TimeWindow("18:00", "24:00")], on: OpeningHours.everyDay)
        XCTAssertEqual(Timetable.openIntervals(late, from: day("2026-09-04"), through: day("2026-09-04"), calendar: calendar()),
                       [interval("2026-09-04T18:00", "2026-09-05T00:00")])
    }

    func testAWindowAcrossTheSpringClockChangeIsShorter() throws {
        let night = OpeningHours([try TimeWindow("00:30", "03:00")], on: OpeningHours.everyDay)
        let open = Timetable.openIntervals(night, from: day("2026-03-29"), through: day("2026-03-29"), calendar: calendar(london))
        XCTAssertEqual(open.first?.duration, 1.5 * hour)
    }

    func testOpeningHoursFeedSlots() throws {
        let open = Timetable.openIntervals(try hours(), from: day("2026-09-05"), through: day("2026-09-05"), calendar: calendar())
        XCTAssertEqual(Timetable.slots(length: hour, in: open).count, 4)
    }

    func testTimesAreChecked() {
        XCTAssertEqual(try DayTime("9:30"), try DayTime(hour: 9, minute: 30))
        XCTAssertEqual(try DayTime("24:00"), .endOfDay)
        XCTAssertThrowsError(try DayTime("24:30"))
        XCTAssertThrowsError(try DayTime("0930"))
        XCTAssertThrowsError(try DayTime("09:5"))
        XCTAssertThrowsError(try TimeWindow("17:00", "09:00")) { error in
            XCTAssertEqual(error as? TimetableError, .badWindow(opens: try! DayTime("17:00"), closes: try! DayTime("09:00")))
        }
        XCTAssertThrowsError(try TimeWindow("09:00", "09:00"))
    }

    func testAWeekAtAGlanceInBritain() throws {
        let lines = Timetable.summary(try hours(), calendar: calendar())
        XCTAssertEqual(lines.map(\.dayLabel), ["Mon–Fri", "Sat", "Sun"])
        XCTAssertEqual(lines.map(\.hoursLabel), ["09:00–12:30, 13:30–17:00", "10:00–14:00", "Closed"])
        XCTAssertEqual(lines.last?.isClosed, true)
    }

    func testAWeekAtAGlanceStartsOnSundayInAmerica() throws {
        let lines = Timetable.summary(try hours(), calendar: calendar(firstWeekday: 1, locale: "en_US"), closedLabel: "Closed today")
        XCTAssertEqual(lines.map(\.dayLabel), ["Sun", "Mon–Fri", "Sat"])
        XCTAssertEqual(lines.first?.hoursLabel, "Closed today")
        XCTAssertTrue(lines[1].hoursLabel.contains("PM"))
    }

    func testTwoNeighbouringDaysAreListedNotRanged() throws {
        let lines = Timetable.summary(OpeningHours([try TimeWindow("09:00", "17:00")], on: OpeningHours.weekdays), calendar: calendar())
        XCTAssertEqual(lines.map(\.dayLabel), ["Mon–Fri", "Sat, Sun"])
    }
}
