//
//  RecurrenceRule+Phrase.swift
//  CalendarCore
//

import Foundation

extension RecurrenceRule {

    /// The rule in words, with what it leaves to the first occurrence filled
    /// in: "every Monday" rather than "every week", "the 4th of every month"
    /// rather than "every month". In the calendar's language for Spanish,
    /// French, German, Italian, Portuguese, Dutch, Japanese, Korean, Chinese,
    /// Russian and Arabic, for the common shapes; otherwise ChronoKit's English.
    ///
    /// - Parameter start: the series' first occurrence.
    public func phrase(from start: Date, calendar: Calendar = .current) -> String {
        Phrasing.describe(self, from: start, calendar: calendar)
    }
}
