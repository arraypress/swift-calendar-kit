//
//  TimeWindow+Day.swift
//  CalendarCore
//

import Foundation

extension TimeWindow {

    /// The whole day, 00:00 to 24:00.
    public static let allDay = try! TimeWindow(opens: .startOfDay, closes: .endOfDay)
}

extension TimeWindow: CustomStringConvertible {

    /// `09:00–17:30`.
    public var description: String { "\(opens)–\(closes)" }
}
