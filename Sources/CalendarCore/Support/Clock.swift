//
//  Clock.swift
//  CalendarCore
//
//  Wall-clock times of day: reading `HH:mm`, and what counts as a time.
//

import Foundation

enum Clock {

    /// 00:00 to 23:59, and 24:00 for the end of the day.
    static func isValid(hour: Int, minute: Int) -> Bool {
        (0...23).contains(hour) && (0...59).contains(minute) || hour == 24 && minute == 0
    }

    /// `09:30` or `9:30`, nothing looser.
    static func parse(_ text: String) throws(TimetableError) -> DayTime {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[1].count == 2, (1...2).contains(parts[0].count),
              let hour = Int(parts[0]), let minute = Int(parts[1]) else {
            throw .unreadableTime(text)
        }
        return try DayTime(hour: hour, minute: minute)
    }

    static func text(_ time: DayTime) -> String {
        String(format: "%02d:%02d", time.hour, time.minute)
    }
}
