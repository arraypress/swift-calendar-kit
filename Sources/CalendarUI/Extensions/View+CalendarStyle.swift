//
//  View+CalendarStyle.swift
//  CalendarUI
//

import SwiftUI

private struct CalendarStyleKey: EnvironmentKey {
    static let defaultValue = CalendarStyle()
}

extension EnvironmentValues {

    /// The style calendar views below this point draw with.
    public var calendarStyle: CalendarStyle {
        get { self[CalendarStyleKey.self] }
        set { self[CalendarStyleKey.self] = newValue }
    }
}

extension View {

    /// Sets the style for every calendar view inside.
    public func calendarStyle(_ style: CalendarStyle) -> some View {
        environment(\.calendarStyle, style)
    }
}
