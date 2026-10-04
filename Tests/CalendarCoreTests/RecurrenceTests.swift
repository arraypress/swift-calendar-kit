//
//  RecurrenceTests.swift
//  CalendarCore
//
//  Repeating series in 2026. 7 September is a Monday; 4 September a Friday.
//

import XCTest
@testable import CalendarCore

final class RecurrenceTests: XCTestCase {

    private func starts(_ rule: RecurrenceRule, from start: String, length: TimeInterval = hour,
                        in range: DateInterval, _ zone: TimeZone = utc, allDay: Bool = false) -> [String] {
        let first = at(start, zone)
        let end = allDay ? first.addingTimeInterval(86_400) : first.addingTimeInterval(length)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.dateFormat = start.contains("T") ? "yyyy-MM-dd'T'HH:mm" : "yyyy-MM-dd"
        return Timetable.occurrences(of: rule, start: first, end: end, isAllDay: allDay, in: range, calendar: calendar(zone))
            .map { formatter.string(from: $0.start) }
    }

    private let september = interval("2026-09-01", "2026-10-01")

    private func rule(_ text: String) -> RecurrenceRule { try! RecurrenceRule(parsing: text) }

    func testDailyAndEveryOtherDay() {
        XCTAssertEqual(starts(rule("FREQ=DAILY"), from: "2026-09-28T09:00", in: september), ["2026-09-28T09:00", "2026-09-29T09:00", "2026-09-30T09:00"])
        XCTAssertEqual(starts(rule("FREQ=DAILY;INTERVAL=2"), from: "2026-09-25T09:00", in: september), ["2026-09-25T09:00", "2026-09-27T09:00", "2026-09-29T09:00"])
    }

    func testWeeklyOnTheStartsWeekday() {
        XCTAssertEqual(starts(rule("FREQ=WEEKLY"), from: "2026-09-07T09:00", in: september),
                       ["2026-09-07T09:00", "2026-09-14T09:00", "2026-09-21T09:00", "2026-09-28T09:00"])
    }

    func testEveryOtherWeekOnTwoDays() {
        XCTAssertEqual(starts(rule("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE"), from: "2026-09-07T18:00", in: september),
                       ["2026-09-07T18:00", "2026-09-09T18:00", "2026-09-21T18:00", "2026-09-23T18:00"])
    }

    func testDaysBeforeTheFirstOccurrenceInItsWeekAreSkipped() {
        XCTAssertEqual(starts(rule("FREQ=WEEKLY;BYDAY=MO,FR"), from: "2026-09-02T09:00", in: interval("2026-09-01", "2026-09-10")),
                       ["2026-09-04T09:00", "2026-09-07T09:00"])
    }

    func testMonthlyOnTheFirstAndFifteenth() {
        XCTAssertEqual(starts(rule("FREQ=MONTHLY;BYMONTHDAY=1,15"), from: "2026-09-01", in: interval("2026-09-01", "2026-11-01"), allDay: true),
                       ["2026-09-01", "2026-09-15", "2026-10-01", "2026-10-15"])
    }

    func testThe31stSkipsShortMonths() {
        XCTAssertEqual(starts(rule("FREQ=MONTHLY"), from: "2026-01-31", in: interval("2026-01-01", "2026-06-01"), allDay: true),
                       ["2026-01-31", "2026-03-31", "2026-05-31"])
    }

    func testTheLastDayOfEveryMonth() {
        XCTAssertEqual(starts(rule("FREQ=MONTHLY;BYMONTHDAY=-1"), from: "2026-01-31", in: interval("2026-01-01", "2026-05-01"), allDay: true),
                       ["2026-01-31", "2026-02-28", "2026-03-31", "2026-04-30"])
    }

    func testTheSecondTuesdayAndTheLastFriday() {
        XCTAssertEqual(starts(rule("FREQ=MONTHLY;BYDAY=2TU"), from: "2026-09-08T19:00", in: interval("2026-09-01", "2026-12-01")),
                       ["2026-09-08T19:00", "2026-10-13T19:00", "2026-11-10T19:00"])
        XCTAssertEqual(starts(rule("FREQ=MONTHLY;BYDAY=-1FR"), from: "2026-09-25T17:00", in: interval("2026-09-01", "2026-12-01")),
                       ["2026-09-25T17:00", "2026-10-30T17:00", "2026-11-27T17:00"])
    }

    func testALeapDayBirthdayOnlyComesInLeapYears() {
        XCTAssertEqual(starts(rule("FREQ=YEARLY"), from: "2024-02-29", in: interval("2024-01-01", "2033-01-01"), allDay: true),
                       ["2024-02-29", "2028-02-29", "2032-02-29"])
    }

    func testThanksgivingIsTheFourthThursdayOfNovember() {
        XCTAssertEqual(starts(rule("FREQ=YEARLY;BYDAY=4TH;BYMONTH=11"), from: "2026-11-26", in: interval("2026-01-01", "2029-01-01"), allDay: true),
                       ["2026-11-26", "2027-11-25", "2028-11-23"])
    }

    func testACountCountsFromTheFirstOccurrenceNotTheRange() {
        XCTAssertEqual(starts(rule("FREQ=WEEKLY;COUNT=3"), from: "2026-09-07T09:00", in: interval("2026-09-15", "2026-12-01")), ["2026-09-21T09:00"])
    }

    func testAnUntilIsInclusive() {
        XCTAssertEqual(starts(rule("FREQ=DAILY;UNTIL=20260909T090000Z"), from: "2026-09-07T09:00", in: september), ["2026-09-07T09:00", "2026-09-08T09:00", "2026-09-09T09:00"])
    }

    func testSkippedDaysAreLeftOutButStillCount() {
        let skipping = try! RecurrenceRule(frequency: .daily, count: 4, exceptions: [at("2026-09-08")])
        XCTAssertEqual(starts(skipping, from: "2026-09-07T09:00", in: september), ["2026-09-07T09:00", "2026-09-09T09:00", "2026-09-10T09:00"])
    }

    func testNineOClockStaysNineOClockAcrossTheClockChange() {
        let found = starts(rule("FREQ=WEEKLY"), from: "2026-10-19T09:00", in: interval("2026-10-01", "2026-11-10", london), london)
        XCTAssertEqual(found, ["2026-10-19T09:00", "2026-10-26T09:00", "2026-11-02T09:00", "2026-11-09T09:00"])
    }

    func testAnOccurrenceAlreadyRunningAtTheRangeStartIsIncluded() {
        let found = starts(rule("FREQ=DAILY"), from: "2026-09-01T23:00", length: 2 * hour, in: interval("2026-09-05", "2026-09-06"))
        XCTAssertEqual(found, ["2026-09-04T23:00", "2026-09-05T23:00"])
    }

    func testALongSeriesJumpsStraightToTheRange() {
        let started = Date()
        let found = starts(rule("FREQ=DAILY"), from: "1990-01-01T09:00", in: interval("2026-09-01", "2026-09-04"))
        XCTAssertEqual(found.count, 3)
        XCTAssertLessThan(Date().timeIntervalSince(started), 0.5)
    }

    // MARK: - Events

    private struct Meeting: RecurringEvent {
        let id: String
        let start: Date
        let end: Date
        var recurrence: RecurrenceRule?
    }

    func testExpandingMixesSeriesAndOneOffsInOrder() {
        let events = [
            Meeting(id: "standup", start: at("2026-09-07T09:00"), end: at("2026-09-07T09:15"), recurrence: rule("FREQ=WEEKLY;BYDAY=MO,TH")),
            Meeting(id: "dentist", start: at("2026-09-08T14:00"), end: at("2026-09-08T15:00")),
            Meeting(id: "old", start: at("2026-08-01T14:00"), end: at("2026-08-01T15:00")),
        ]
        let found = Timetable.expand(events, in: interval("2026-09-07", "2026-09-14"), calendar: calendar())
        XCTAssertEqual(found.map(\.event.id), ["standup", "dentist", "standup"])
        XCTAssertEqual(found[2].start, at("2026-09-10T09:00"))
        XCTAssertEqual(found[2].end, at("2026-09-10T09:15"))
        XCTAssertNotEqual(found[0].id, found[2].id)
    }

    func testOccurrencesWorkInLayouts() {
        let standup = Meeting(id: "standup", start: at("2026-09-07T09:00"), end: at("2026-09-07T10:00"), recurrence: rule("FREQ=DAILY"))
        let week = Timetable.expand([standup], in: interval("2026-09-07", "2026-09-14"), calendar: calendar())
        XCTAssertEqual(Timetable.layout(week, on: at("2026-09-10"), calendar: calendar()).timed.count, 1)
    }

    // MARK: - Words

    func testRRuleTextAndWordsExpandAlike() {
        let range = interval("2026-09-01", "2026-12-01")
        XCTAssertEqual(starts(rule("FREQ=MONTHLY;BYDAY=-1FR"), from: "2026-09-25T17:00", in: range),
                       starts(rule("the last friday of every month"), from: "2026-09-25T17:00", in: range))
    }

    private func words(_ text: String, _ start: String) -> String {
        rule(text).phrase(from: at(start), calendar: calendar())
    }

    func testPhrasesSpellOutWhatTheFirstOccurrenceDecides() {
        XCTAssertEqual(words("FREQ=WEEKLY", "2026-09-07"), "Every Monday")
        XCTAssertEqual(words("FREQ=WEEKLY;INTERVAL=2", "2026-09-10"), "Every 2 weeks on Thursday")
        XCTAssertEqual(words("FREQ=MONTHLY", "2026-09-04"), "The 4th of every month")
        XCTAssertEqual(words("FREQ=YEARLY", "2026-09-04"), "Every year on 4 September")
    }

    func testPhrasesThatSayEverythingAreLeftAlone() {
        XCTAssertEqual(words("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE", "2026-09-07"), "Every 2 weeks on Monday and Wednesday")
        XCTAssertEqual(words("FREQ=MONTHLY;BYDAY=-1FR;COUNT=12", "2026-09-25"), "The last Friday of every month, 12 times")
        XCTAssertEqual(words("FREQ=DAILY", "2026-09-07"), "Every day")
    }
}
