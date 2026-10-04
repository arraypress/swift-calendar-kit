//
//  MonthGrid+Days.swift
//  CalendarCore
//

import Foundation

extension MonthGrid {

    /// Every box, row by row.
    public var days: [GridDay] { weeks.flatMap { $0 } }
}
