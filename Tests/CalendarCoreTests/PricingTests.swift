//
//  PricingTests.swift
//  CalendarCore
//

import XCTest
@testable import CalendarCore

final class PricingTests: XCTestCase {

    private let rates = NightlyRates(
        nightly: 100, weekendNightly: 150,
        seasons: [
            Season(name: "Summer", from: day("2026-08-01"), through: day("2026-08-31"), nightly: 200, weekendNightly: 250),
            Season(name: "Bank holiday", from: day("2026-08-29"), through: day("2026-08-30"), nightly: 300),
        ],
        discounts: [StayDiscount(minimumNights: 7, percent: 10), StayDiscount(minimumNights: 28, percent: 25)],
        perStayFee: 50
    )

    func testWeekendNightsAreFridayAndSaturday() {
        let quote = Timetable.quote(Stay(checkIn: day("2026-09-03"), checkOut: day("2026-09-07")), rates: rates)
        XCTAssertEqual(quote.nights.map(\.amount), [100, 150, 150, 100])
        XCTAssertEqual(quote.nights.map(\.isWeekend), [false, true, true, false])
        XCTAssertEqual(quote.subtotal, 500)
        XCTAssertNil(quote.discount)
        XCTAssertEqual(quote.total, 550)
    }

    func testAStayAcrossASeasonEndIsPricedNightByNight() {
        let quote = Timetable.quote(Stay(checkIn: day("2026-08-27"), checkOut: day("2026-09-02")), rates: rates)
        XCTAssertEqual(quote.nights.map(\.amount), [200, 250, 300, 300, 200, 100])
        XCTAssertEqual(quote.nights.map(\.season), ["Summer", "Summer", "Bank holiday", "Bank holiday", "Summer", nil])
    }

    func testTheBiggestDiscountQualifyingApplies() {
        let plain = NightlyRates(nightly: 100, discounts: rates.discounts)
        let week = Timetable.quote(Stay(checkIn: day("2026-10-05"), nights: 7), rates: plain)
        XCTAssertEqual(week.discountAmount, 70)
        XCTAssertEqual(week.total, 630)
        let month = Timetable.quote(Stay(checkIn: day("2026-10-05"), nights: 28), rates: plain)
        XCTAssertEqual(month.discount?.percent, 25)
        XCTAssertEqual(month.total, 2100)
    }

    func testTheDiscountLeavesTheFeeAlone() {
        let quote = Timetable.quote(Stay(checkIn: day("2026-10-05"), nights: 7), rates: rates)
        XCTAssertEqual(quote.subtotal, 800)
        XCTAssertEqual(quote.total, 800 - 80 + 50)
    }

    func testDecimalsStayExact() {
        let quote = Timetable.quote(Stay(checkIn: day("2026-10-05"), nights: 3), rates: NightlyRates(nightly: Decimal(string: "99.99")!))
        XCTAssertEqual(quote.total, Decimal(string: "299.97")!)
    }

    func testAnInvalidStayCostsNothing() {
        let quote = Timetable.quote(Stay(checkIn: day("2026-10-05"), nights: 0), rates: rates)
        XCTAssertTrue(quote.nights.isEmpty)
        XCTAssertEqual(quote.total, 0)
    }
}
