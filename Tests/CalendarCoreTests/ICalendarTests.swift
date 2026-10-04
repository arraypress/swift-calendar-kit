//
//  ICalendarTests.swift
//  CalendarCore
//
//  .ics files in and out: the content-line rules of RFC 5545 §3.1, the three
//  forms a time takes, and edited occurrences of a series.
//

import XCTest
@testable import CalendarCore

final class ICalendarTests: XCTestCase {

    private let file = """
    BEGIN:VCALENDAR\r
    VERSION:2.0\r
    X-WR-CALNAME:Lettings\r
    BEGIN:VEVENT\r
    UID:viewing-1\r
    DTSTART:20261005T090000Z\r
    DTEND:20261005T093000Z\r
    SUMMARY:Viewing\\, Flat 3\r
    DESCRIPTION:Bring keys\\nand the inventory\r
    LOCATION:Flat 3\\; Harbour Road\r
    BEGIN:VALARM\r
    TRIGGER:-PT15M\r
    DESCRIPTION:Reminder\r
    END:VALARM\r
    END:VEVENT\r
    BEGIN:VEVENT\r
    UID:stay-1\r
    DTSTART;VALUE=DATE:20261010\r
    DTEND;VALUE=DATE:20261013\r
    SUMMARY:Mill House · Ada Lovelace — a long stay with a deliberately long title that has to fold\r
      across two lines\r
    END:VEVENT\r
    BEGIN:VEVENT\r
    UID:standup\r
    DTSTART;TZID=Europe/London:20261005T093000\r
    DURATION:PT15M\r
    RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=4\r
    SUMMARY:Standup\r
    END:VEVENT\r
    BEGIN:VEVENT\r
    UID:standup\r
    RECURRENCE-ID;TZID=Europe/London:20261012T093000\r
    DTSTART;TZID=Europe/London:20261012T110000\r
    DTEND;TZID=Europe/London:20261012T111500\r
    SUMMARY:Standup (moved)\r
    END:VEVENT\r
    BEGIN:VEVENT\r
    UID:floating\r
    DTSTART:20261006T140000\r
    SUMMARY:Floating\r
    END:VEVENT\r
    BEGIN:VEVENT\r
    UID:odd\r
    DTSTART:20261007T080000Z\r
    RRULE:FREQ=YEARLY;BYWEEKNO=20\r
    SUMMARY:Odd rule\r
    END:VEVENT\r
    END:VCALENDAR\r

    """

    private func read() throws -> ICalendarImport { try ICalendar.read(file, calendar: calendar(london)) }
    private func event(_ id: String) throws -> ICalendarEvent { try read().events.first { $0.id == id }! }

    func testTheNameAndEveryEvent() throws {
        let read = try read()
        XCTAssertEqual(read.name, "Lettings")
        XCTAssertEqual(read.events.map(\.id).sorted(), ["floating", "odd", "standup", "standup#1791793800", "stay-1", "viewing-1"].sorted())
    }

    func testTextIsUnescapedAndAlarmsAreSkipped() throws {
        let viewing = try event("viewing-1")
        XCTAssertEqual(viewing.title, "Viewing, Flat 3")
        XCTAssertEqual(viewing.notes, "Bring keys\nand the inventory")
        XCTAssertEqual(viewing.location, "Flat 3; Harbour Road")
        XCTAssertEqual(viewing.start, at("2026-10-05T09:00"))
        XCTAssertEqual(viewing.end, at("2026-10-05T09:30"))
    }

    func testFoldedLinesAreJoinedAndDatesAreAllDay() throws {
        let stay = try event("stay-1")
        XCTAssertEqual(stay.title, "Mill House · Ada Lovelace — a long stay with a deliberately long title that has to fold across two lines")
        XCTAssertTrue(stay.isAllDay)
        XCTAssertEqual(stay.start, at("2026-10-10", london))
        XCTAssertEqual(stay.end, at("2026-10-13", london))
    }

    func testAZonedTimeAndADuration() throws {
        let standup = try event("standup")
        XCTAssertEqual(standup.start, at("2026-10-05T09:30", london))
        XCTAssertEqual(standup.end.timeIntervalSince(standup.start), 15 * 60)
        XCTAssertEqual(standup.recurrence?.count, 4)
    }

    func testAFloatingTimeIsReadInTheCalendarsZone() throws {
        XCTAssertEqual(try event("floating").start, at("2026-10-06T14:00", london))
        XCTAssertEqual(try ICalendar.read(file, calendar: calendar()).events.first { $0.id == "floating" }?.start, at("2026-10-06T14:00"))
    }

    func testAnEditedOccurrenceReplacesItsDateInTheSeries() throws {
        let read = try read()
        let occurrences = Timetable.expand(read.events.filter { $0.id.hasPrefix("standup") },
                                           in: interval("2026-10-01", "2026-11-01", london), calendar: calendar(london))
        let formatter = DateFormatter()
        formatter.timeZone = london
        formatter.dateFormat = "MM-dd HH:mm"
        XCTAssertEqual(occurrences.map { formatter.string(from: $0.start) }, ["10-05 09:30", "10-12 11:00", "10-19 09:30", "10-26 09:30"])
    }

    func testAnUnusableRuleIsAWarningNotASilentDrop() throws {
        let read = try read()
        XCTAssertNil(try event("odd").recurrence)
        XCTAssertEqual(read.warnings.count, 1)
        XCTAssertTrue(read.warnings[0].hasPrefix("Odd rule:"))
    }

    func testTextThatIsNotICalendarIsRefused() {
        XCTAssertThrowsError(try ICalendar.read("hello", calendar: calendar())) { error in
            XCTAssertEqual(error as? TimetableError, .notICalendar)
        }
    }

    func testDurations() {
        XCTAssertEqual(ICSReader.parseDuration("PT1H30M")?.seconds, 5400)
        XCTAssertEqual(ICSReader.parseDuration("P1W")?.days, 7)
        XCTAssertEqual(ICSReader.parseDuration("P1DT12H")?.days, 1)
        XCTAssertEqual(ICSReader.parseDuration("P1DT12H")?.seconds, 43_200)
        XCTAssertNil(ICSReader.parseDuration("-PT5M"))
        XCTAssertNil(ICSReader.parseDuration("1H"))
    }

    // MARK: - Writing

    private let stamp = at("2026-10-04T12:00")

    func testWritingFoldsEscapesAndUsesCRLF() {
        let event = BasicEvent(id: "a", title: "Viewing, Flat 3; " + String(repeating: "long ", count: 20), start: at("2026-10-05T09:00"),
                               end: at("2026-10-05T09:30"))
        let text = ICalendar.write([event], name: "Lettings", calendar: calendar(london), stamp: stamp, title: \.title)
        XCTAssertTrue(text.hasPrefix("BEGIN:VCALENDAR\r\nVERSION:2.0\r\n"))
        XCTAssertTrue(text.contains("SUMMARY:Viewing\\, Flat 3\\; long"))
        XCTAssertTrue(text.contains("\r\n long") || text.contains("\r\n  long") || text.contains("\r\n "))
        XCTAssertTrue(text.contains("DTSTART:20261005T090000Z"))
        XCTAssertTrue(text.split(separator: "\r\n", omittingEmptySubsequences: false).allSatisfy { $0.utf8.count <= 75 })
    }

    func testARepeatingEventIsWrittenInItsZone() throws {
        let standup = try event("standup")
        let text = ICalendar.write([standup], calendar: calendar(london), stamp: stamp)
        XCTAssertTrue(text.contains("DTSTART;TZID=Europe/London:20261005T093000"))
        XCTAssertTrue(text.contains("RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=4"))
    }

    func testFilesRoundTrip() throws {
        let original = try read()
        let again = try ICalendar.read(ICalendar.write(original.events, name: original.name, calendar: calendar(london), stamp: stamp),
                                       calendar: calendar(london))
        XCTAssertEqual(again.name, "Lettings")
        for event in original.events {
            let copy = try XCTUnwrap(again.events.first { $0.id == event.id }, event.id)
            XCTAssertEqual(copy.title, event.title)
            XCTAssertEqual(copy.start, event.start, event.id)
            XCTAssertEqual(copy.end, event.end, event.id)
            XCTAssertEqual(copy.isAllDay, event.isAllDay)
            XCTAssertEqual(copy.notes, event.notes)
            XCTAssertEqual(copy.location, event.location)
            XCTAssertEqual(copy.recurrence?.rruleString, event.recurrence?.rruleString, event.id)
        }
    }
}
