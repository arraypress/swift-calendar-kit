//
//  Stay+Nights.swift
//  CalendarCore
//

import Foundation

extension Stay {

    /// How many nights; zero or less for dates the wrong way round.
    public var nightCount: Int { Stays.nightCount(self) }

    /// Each night, named by the day it starts on.
    public var nights: [CalendarDay] { Stays.nights(of: self) }
}

extension Stay: CustomStringConvertible {

    /// `2026-09-04 → 2026-09-07`.
    public var description: String { "\(checkIn) → \(checkOut)" }
}

extension StayCheck {

    /// Whether the stay can be booked.
    public var isAvailable: Bool { self == .available }
}
