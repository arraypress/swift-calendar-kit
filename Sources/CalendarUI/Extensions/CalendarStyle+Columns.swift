//
//  CalendarStyle+Columns.swift
//  CalendarUI
//

import SwiftUI

extension CalendarStyle {

    /// The width of a timeline's leading label column, wider when it also
    /// shows a second time zone's hours. The all-day row and week header
    /// line up with it.
    func labelColumnWidth(secondZone: Bool) -> CGFloat {
        hourLabelWidth * (secondZone ? 1.8 : 1)
    }
}
