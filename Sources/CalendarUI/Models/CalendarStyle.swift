//
//  CalendarStyle.swift
//  CalendarUI
//

import SwiftUI

/// The measurements and colours every calendar view shares. Set it once, high
/// up, with ``SwiftUI/View/calendarStyle(_:)``.
public struct CalendarStyle: Sendable {

    /// The height of one hour on a timeline.
    public var hourHeight: CGFloat = 56

    /// The width of the hour labels down a timeline's leading edge.
    public var hourLabelWidth: CGFloat = 52

    /// The shortest an event is drawn, which is also how much room it claims
    /// when deciding what overlaps.
    public var minimumEventDuration: TimeInterval = 30 * 60

    /// The height of an all-day bar.
    public var allDayBarHeight: CGFloat = 24

    /// The most all-day lanes shown before a "+N" count takes over.
    public var maximumAllDayLanes: Int = 3

    /// The hour a timeline scrolls to when it appears.
    public var firstVisibleHour: Int = 8

    /// Today's circle, and the line marking the current time.
    public var todayColor: Color = .red

    /// The circle behind the selected day.
    public var selectionColor: Color = .primary

    /// How round a tile's corners are.
    public var tileCornerRadius: CGFloat = 8

    /// The most event pills under a day in a month grid.
    public var monthPillLimit: Int = 3

    /// The width of one day on a bookings board.
    public var boardDayWidth: CGFloat = 44

    /// The width of the resource names down a bookings board's leading edge.
    public var boardLabelWidth: CGFloat = 130

    /// The height of one lane of bars on a bookings board.
    public var boardBarHeight: CGFloat = 34

    /// The default style.
    public init() {}
}
