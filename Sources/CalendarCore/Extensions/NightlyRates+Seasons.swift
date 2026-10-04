//
//  NightlyRates+Seasons.swift
//  CalendarCore
//

import Foundation

extension NightlyRates {

    /// The season a night falls in, if any; the later of two that overlap.
    public func season(for night: CalendarDay) -> Season? {
        Stays.season(for: night, in: self)
    }
}
