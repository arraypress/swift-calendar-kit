//
//  MetricsTests.swift
//  CalendarCore
//
//  Rental figures over September 2026 — thirty nights — worked by hand.
//

import XCTest
@testable import CalendarCore

final class MetricsTests: XCTestCase {

    private let september = (first: day("2026-09-01"), last: day("2026-09-30"))

    private func record(_ checkIn: String, nights: Int, _ amount: Decimal, fee: ChannelFee? = nil, booked: String? = nil) -> StayRecord {
        StayRecord(stay: Stay(checkIn: day(checkIn), nights: nights), amount: amount, fee: fee, bookedOn: booked.map(day))
    }

    private func measure(_ records: [StayRecord], units: Int = 1, unavailable: Int = 0) -> StayMetrics {
        Timetable.metrics(records, from: september.first, through: september.last, units: units, unavailableNights: unavailable)
    }

    func testOccupancyAndTheTwoRates() {
        // 6 nights for 600 and 9 nights for 1,350: 15 of 30 nights, 1,950 earned.
        let m = measure([record("2026-09-01", nights: 6, 600), record("2026-09-10", nights: 9, 1350)])
        XCTAssertEqual(m.availableNights, 30)
        XCTAssertEqual(m.bookedNights, 15)
        XCTAssertEqual(m.occupancy, 0.5)
        XCTAssertEqual(m.revenue, 1950)
        XCTAssertEqual(m.averageNightlyRate, 130)
        XCTAssertEqual(m.revenuePerAvailableNight, 65)
    }

    func testAStayAcrossTheMonthEndEarnsEachMonthItsOwnNights() {
        // 28 Sept to 3 Oct: 5 nights at 100, three of them in September.
        let m = measure([record("2026-09-28", nights: 5, 500)])
        XCTAssertEqual(m.bookedNights, 3)
        XCTAssertEqual(m.revenue, 300)
        XCTAssertEqual(m.arrivals, 1)
    }

    func testAStayFromLastMonthIsNotAnArrival() {
        let m = measure([record("2026-08-29", nights: 5, 500)])
        XCTAssertEqual(m.bookedNights, 2)
        XCTAssertEqual(m.revenue, 200)
        XCTAssertEqual(m.arrivals, 0)
        XCTAssertNil(m.averageStayLength)
    }

    func testUnitsAndNightsNotOffered() {
        let m = measure([record("2026-09-01", nights: 30, 3000)], units: 3, unavailable: 10)
        XCTAssertEqual(m.availableNights, 80)
        XCTAssertEqual(m.occupancy, 30.0 / 80)
        XCTAssertEqual(m.revenuePerAvailableNight, Decimal(3000) / 80)
    }

    func testFeesAreTakenNightByNightToo() {
        // 15% plus 30 on a 1,000 stay is 180; half its nights fall in September.
        let fee = ChannelFee(flat: 30, percent: 15)
        let m = measure([record("2026-09-28", nights: 6, 1000, fee: fee)])
        XCTAssertEqual(m.revenue, 500)
        XCTAssertEqual(m.fees, 90)
        XCTAssertEqual(m.payout, 410)
    }

    func testAFeeNeverExceedsTheAmount() {
        XCTAssertEqual(ChannelFee(flat: 50).fee(on: 20), 20)
        XCTAssertEqual(ChannelFee(percent: 3).payout(from: 400), 388)
    }

    func testLengthAndLeadTimeAreOfArrivals() {
        let m = measure([
            record("2026-09-05", nights: 3, 300, booked: "2026-08-06"),   // 30 days ahead
            record("2026-09-20", nights: 7, 700, booked: "2026-09-10"),   // 10 days ahead
            record("2026-09-25", nights: 2, 200),                         // booking day unknown
        ])
        XCTAssertEqual(m.arrivals, 3)
        XCTAssertEqual(m.averageStayLength, 4)
        XCTAssertEqual(m.averageLeadTime, 20)
    }

    func testANightWithNothingBookedHasNoRate() {
        let m = measure([])
        XCTAssertEqual(m.occupancy, 0)
        XCTAssertNil(m.averageNightlyRate)
        XCTAssertEqual(m.revenuePerAvailableNight, 0)
    }

    func testADoubleBookingCountsTwice() {
        let m = measure([record("2026-09-01", nights: 2, 200), record("2026-09-01", nights: 2, 200)])
        XCTAssertEqual(m.bookedNights, 4)
    }
}
