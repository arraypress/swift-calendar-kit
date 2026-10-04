//
//  PhraseLanguageTests.swift
//  CalendarCore
//
//  Repeat rules said in each language, from a series starting on Monday
//  7 September 2026. The grammar each one pins: Russian's case and gender
//  after "в"/"во", Italian's feminine Sunday, Portuguese's feminine
//  "-feira" days, French elision, Spanish and French plural weekdays,
//  Arabic digits — and the English fallback for shapes not covered.
//

import XCTest
@testable import CalendarCore

final class PhraseLanguageTests: XCTestCase {

    private func say(_ rrule: String, _ locale: String) throws -> String {
        try RecurrenceRule(parsing: rrule).phrase(from: at("2026-09-07T09:00"), calendar: calendar(locale: locale))
    }

    func testSpanish() throws {
        XCTAssertEqual(try say("FREQ=WEEKLY;BYDAY=SA,SU", "es_ES"), "Todos los sábados y domingos")
        XCTAssertEqual(try say("FREQ=MONTHLY;BYMONTHDAY=1,15", "es_ES"), "Los días 1 y 15 de cada mes")
        XCTAssertEqual(try say("FREQ=YEARLY;BYDAY=4TH;BYMONTH=11", "es_ES"), "El cuarto jueves de noviembre de cada año")
    }

    func testFrench() throws {
        XCTAssertEqual(try say("FREQ=WEEKLY", "fr_FR"), "Tous les lundis")
        XCTAssertEqual(try say("FREQ=MONTHLY;BYMONTHDAY=1,15", "fr_FR"), "Le 1er et le 15 de chaque mois")
        XCTAssertEqual(try say("FREQ=YEARLY;BYDAY=1SU;BYMONTH=10", "fr_FR"), "Le premier dimanche d’octobre de chaque année")
    }

    func testGerman() throws {
        XCTAssertEqual(try say("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE", "de_DE"), "Alle 2 Wochen am Montag und Mittwoch")
        XCTAssertEqual(try say("FREQ=MONTHLY;BYDAY=2TU", "de_DE"), "Jeden zweiten Dienstag im Monat")
        XCTAssertEqual(try say("FREQ=MONTHLY;BYDAY=-1SU;COUNT=5", "de_DE"), "Jeden letzten Sonntag im Monat, 5-mal")
    }

    func testItalian() throws {
        XCTAssertEqual(try say("FREQ=MONTHLY;BYDAY=-1SU", "it_IT"), "L’ultima domenica di ogni mese")
        XCTAssertEqual(try say("FREQ=MONTHLY;BYDAY=2TU", "it_IT"), "Il secondo martedì di ogni mese")
    }

    func testPortuguese() throws {
        XCTAssertEqual(try say("FREQ=WEEKLY", "pt_BR"), "Toda segunda-feira")
        XCTAssertEqual(try say("FREQ=MONTHLY;BYDAY=2TU", "pt_BR"), "Na segunda terça-feira de cada mês")
        XCTAssertEqual(try say("FREQ=MONTHLY;BYDAY=-1SU", "pt_BR"), "No último domingo de cada mês")
    }

    func testDutch() throws {
        XCTAssertEqual(try say("FREQ=MONTHLY;BYMONTHDAY=1,15", "nl_NL"), "Elke maand op de 1e en 15e")
    }

    func testJapaneseKoreanAndChinese() throws {
        XCTAssertEqual(try say("FREQ=MONTHLY;BYDAY=2TU", "ja_JP"), "毎月第2火曜日")
        XCTAssertEqual(try say("FREQ=YEARLY;BYDAY=4TH;BYMONTH=11", "ko_KR"), "매년 11월 넷째 목요일")
        XCTAssertEqual(try say("FREQ=WEEKLY;BYDAY=SA,SU", "zh_Hans_CN"), "每周六、周日")
        XCTAssertEqual(try say("FREQ=YEARLY;BYDAY=4TH;BYMONTH=11", "zh_Hans_CN"), "每年11月的第4个星期四")
        XCTAssertEqual(try say("FREQ=MONTHLY;BYDAY=-1SU", "zh_Hant_TW"), "每月最後一個星期日")
    }

    func testRussianCaseAndGender() throws {
        XCTAssertEqual(try say("FREQ=WEEKLY;BYDAY=SA,SU", "ru_RU"), "По субботам и воскресеньям")
        XCTAssertEqual(try say("FREQ=MONTHLY;BYDAY=2TU", "ru_RU"), "Во второй вторник каждого месяца")
        XCTAssertEqual(try say("FREQ=MONTHLY;BYDAY=2WE", "ru_RU"), "Во вторую среду каждого месяца")
        XCTAssertEqual(try say("FREQ=MONTHLY;BYDAY=-1SU", "ru_RU"), "В последнее воскресенье каждого месяца")
        XCTAssertEqual(try say("FREQ=DAILY;INTERVAL=5", "ru_RU"), "Каждые 5 дней")
        XCTAssertEqual(try say("FREQ=DAILY;INTERVAL=3", "ru_RU"), "Каждые 3 дня")
    }

    func testArabicUsesItsDigits() throws {
        XCTAssertEqual(try say("FREQ=MONTHLY;BYDAY=2TU", "ar_SA"), "في الثلاثاء الثاني من كل شهر")
        XCTAssertEqual(try say("FREQ=DAILY;INTERVAL=3", "ar_SA"), "كل ٣ أيام")
        XCTAssertEqual(try say("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO", "ar_SA"), "كل أسبوعين يوم الاثنين")
    }

    func testRareShapesFallBackToEnglish() throws {
        XCTAssertEqual(try say("FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=1", "fr_FR"), try say("FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=1", "en_GB"))
        XCTAssertEqual(try say("FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1", "de_DE"),
                       try say("FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1", "en_GB"))
    }
}
