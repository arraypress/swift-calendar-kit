//
//  TimedPlacement+Geometry.swift
//  CalendarCore
//

import Foundation

extension TimedPlacement {

    /// The left edge as a fraction of the day column's width.
    public var leading: Double { Double(column) / Double(columns) }

    /// The width as a fraction of the day column's width.
    public var width: Double { Double(span) / Double(columns) }
}

extension LaneBar {

    /// How many days the bar spans.
    public var length: Int { lastDay - firstDay + 1 }
}
