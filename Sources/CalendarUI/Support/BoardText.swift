//
//  BoardText.swift
//  CalendarUI
//
//  The words on a board's bars.
//

import Foundation

enum BoardText {

    /// "3 nights", or "3 days" when bookings are not counted in nights.
    static func length<E: CalendarEvent>(of event: E, nights: Bool, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: event.start), to: calendar.startOfDay(for: event.end)).day ?? 0
        let count = max(days, 1)
        return nights ? String(localized: "\(count) nights", bundle: .module) : String(localized: "\(count) days", bundle: .module)
    }
}
