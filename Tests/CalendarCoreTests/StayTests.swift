//
//  StayTests.swift
//  CalendarCore
//
//  Nightly bookings in late summer 2026. The 4th of September is a Friday;
//  the 30th of August a Sunday.
//

import XCTest
@testable import CalendarCore

final class StayTests: XCTestCase {

    private let booked = [Stay(checkIn: day("2026-09-01"), checkOut: day("2026-09-04"))]

    func testNightsAreCountedBetweenTheDays() {
        let stay = Stay(checkIn: day("2026-09-04"), checkOut: day("2026-09-07"))
        XCTAssertEqual(stay.nightCount, 3)
        XCTAssertEqual(stay.nights, [day("2026-09-04"), day("2026-09-05"), day("2026-09-06")])
        XCTAssertEqual(Stay(checkIn: day("2026-12-30"), nights: 4).checkOut, day("2027-01-03"))
    }

    func testOneGuestCanArriveTheDayAnotherLeaves() {
        let next = Stay(checkIn: day("2026-09-04"), checkOut: day("2026-09-07"))
        XCTAssertEqual(Timetable.check(next, against: booked), .available)
        XCTAssertEqual(Timetable.check(next, against: booked, rules: StayRules(sameDayTurnover: false)), .clashes([0]))
    }

    func testOverlappingNightsClash() {
        XCTAssertEqual(Timetable.check(Stay(checkIn: day("2026-09-03"), checkOut: day("2026-09-06")), against: booked), .clashes([0]))
        XCTAssertEqual(Timetable.check(Stay(checkIn: day("2026-08-28"), checkOut: day("2026-09-10")), against: booked), .clashes([0]))
    }

    func testDatesTheWrongWayRoundAreInvalid() {
        XCTAssertEqual(Timetable.check(Stay(checkIn: day("2026-09-04"), checkOut: day("2026-09-04"))), .invalidDates)
        XCTAssertEqual(Timetable.check(Stay(checkIn: day("2026-09-04"), checkOut: day("2026-09-02"))), .invalidDates)
    }

    func testLengthRules() {
        let rules = StayRules(minimumNights: 2, maximumNights: 14)
        XCTAssertEqual(Timetable.check(Stay(checkIn: day("2026-09-10"), nights: 1), rules: rules), .tooShort(minimum: 2))
        XCTAssertEqual(Timetable.check(Stay(checkIn: day("2026-09-10"), nights: 15), rules: rules), .tooLong(maximum: 14))
        XCTAssertTrue(Timetable.check(Stay(checkIn: day("2026-09-10"), nights: 14), rules: rules).isAvailable)
    }

    func testASeasonsMinimumIsJudgedByTheCheckInNight() {
        let rates = NightlyRates(nightly: 100, seasons: [Season(name: "Summer", from: day("2026-08-01"), through: day("2026-08-31"),
                                                                 nightly: 200, minimumNights: 7)])
        XCTAssertEqual(Timetable.check(Stay(checkIn: day("2026-08-10"), nights: 3), rates: rates), .tooShort(minimum: 7))
        XCTAssertEqual(Timetable.check(Stay(checkIn: day("2026-07-30"), nights: 3), rates: rates), .available)
    }

    func testCheckInDaysForAPicker() {
        let booked = [Stay(checkIn: day("2026-09-05"), checkOut: day("2026-09-08"))]
        let days = Timetable.checkInDays(from: day("2026-09-01"), through: day("2026-09-10"), booked: booked,
                                         rules: StayRules(minimumNights: 2))
        XCTAssertEqual(days, ["2026-09-01", "2026-09-02", "2026-09-03", "2026-09-08", "2026-09-09", "2026-09-10"].map(day))
    }

    func testCheckOutDaysStopAtTheNextBooking() {
        let booked = [Stay(checkIn: day("2026-09-05"), checkOut: day("2026-09-08"))]
        let days = Timetable.checkOutDays(after: day("2026-09-01"), booked: booked, rules: StayRules(minimumNights: 2))
        XCTAssertEqual(days, ["2026-09-03", "2026-09-04", "2026-09-05"].map(day))
    }

    func testCheckOutDaysRespectTheMaximum() {
        let days = Timetable.checkOutDays(after: day("2026-09-01"), booked: [], rules: StayRules(maximumNights: 3))
        XCTAssertEqual(days, ["2026-09-02", "2026-09-03", "2026-09-04"].map(day))
    }

    func testBookedNights() {
        XCTAssertEqual(Timetable.bookedNights(booked), Set(["2026-09-01", "2026-09-02", "2026-09-03"].map(day)))
    }
}
