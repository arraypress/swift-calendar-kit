//
//  BoardRow+Occupancy.swift
//  CalendarCore
//

import Foundation

extension BoardRow {

    /// The share of the days with something booked, 0 to 1.
    public var occupancy: Double { Listings.occupancy(isFree) }
}

extension HoursLine {

    /// Whether the days are closed.
    public var isClosed: Bool { windows.isEmpty }
}
