//
//  AppleCalendarTests.swift
//  CalendarEventKit
//
//  What can be checked without calendar access: turning EventKit's values
//  into the views' values. Reading and writing a real calendar needs a
//  signed app with permission, and is not done here.
//

#if canImport(EventKit) && !os(tvOS)
import XCTest
import EventKit
@testable import CalendarEventKit

@MainActor
final class AppleCalendarTests: XCTestCase {

    func testEventKitRulesReadAsChronoKitRules() throws {
        let fortnightly = EKRecurrenceRule(recurrenceWith: .weekly, interval: 2,
                                           daysOfTheWeek: [EKRecurrenceDayOfWeek(.monday), EKRecurrenceDayOfWeek(.wednesday)],
                                           daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheYear: nil,
                                           setPositions: nil, end: EKRecurrenceEnd(occurrenceCount: 6))
        let rule = try XCTUnwrap(EventKitRules.rule(fortnightly))
        XCTAssertEqual(rule.frequency, .weekly)
        XCTAssertEqual(rule.interval, 2)
        XCTAssertEqual(Set(rule.byDay.map(\.weekday)), [.monday, .wednesday])
        XCTAssertEqual(rule.count, 6)
    }

    func testTheLastFridayOfTheMonth() throws {
        let lastFriday = EKRecurrenceRule(recurrenceWith: .monthly, interval: 1,
                                          daysOfTheWeek: [EKRecurrenceDayOfWeek(.friday, weekNumber: -1)],
                                          daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheYear: nil,
                                          setPositions: nil, end: nil)
        let rule = try XCTUnwrap(EventKitRules.rule(lastFriday))
        XCTAssertEqual(rule.byDay.first?.ordinal, -1)
        XCTAssertEqual(rule.byDay.first?.weekday, .friday)
    }

    func testAnEventBecomesAValueWithADistinctID() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = "Standup"
        event.startDate = Date(timeIntervalSince1970: 1_791_000_000)
        event.endDate = event.startDate.addingTimeInterval(900)
        event.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil))
        let value = AppleCalendarEvent(event)
        XCTAssertEqual(value.title, "Standup")
        XCTAssertEqual(value.end.timeIntervalSince(value.start), 900)
        XCTAssertTrue(value.isRecurring)
        XCTAssertEqual(value.recurrence?.frequency, .daily)
        XCTAssertEqual(value.id.start, event.startDate)
    }

    func testAnUntitledEventGetsAName() {
        let event = EKEvent(eventStore: EKEventStore())
        event.startDate = Date(timeIntervalSince1970: 1_791_000_000)
        event.endDate = event.startDate
        XCTAssertFalse(AppleCalendarEvent(event).title.isEmpty)
    }

    func testAllDayEndsMeetInTheMiddle() {
        let event = EKEvent(eventStore: EKEventStore())
        let calendar = Calendar.current
        let first = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_791_000_000))
        event.isAllDay = true
        event.startDate = first
        event.endDate = calendar.date(byAdding: .day, value: 3, to: first)!.addingTimeInterval(-1)  // three days, EventKit's way
        let value = AppleCalendarEvent(event)
        XCTAssertEqual(value.end, calendar.date(byAdding: .day, value: 3, to: first))
        XCTAssertEqual(EventKitRules.inclusiveEnd(value.end, start: value.start), event.endDate)
    }
}
#endif
