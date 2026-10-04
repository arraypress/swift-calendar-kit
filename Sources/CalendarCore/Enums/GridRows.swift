//
//  GridRows.swift
//  CalendarCore
//

import Foundation

/// How many weeks a ``MonthGrid`` holds.
public enum GridRows: Sendable, Hashable {

    /// As many as the month needs: four, five or six.
    case fitted

    /// Always six, so swiping between months never changes the view's height.
    case six
}
