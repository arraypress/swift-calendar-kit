//
//  DayNumber.swift
//  CalendarUI
//

import SwiftUI

/// A day's number in a circle: filled for the selection, red text for today.
struct DayNumber: View {

    @Environment(\.calendarStyle) private var style
    let day: Date
    let calendar: Calendar
    var isSelected = false
    var font: Font = .callout

    var body: some View {
        let today = calendar.isToday(day)
        Text(calendar.dayNumber(day))
            .font(font.weight(today || isSelected ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(foreground(today: today))
            .frame(width: 30, height: 30)
            .background {
                if isSelected { Circle().fill(today ? style.todayColor : style.selectionColor) }
            }
    }

    private func foreground(today: Bool) -> AnyShapeStyle {
        switch (isSelected, today) {
        case (true, true): AnyShapeStyle(.white)
        case (true, false): AnyShapeStyle(.background)
        case (false, true): AnyShapeStyle(style.todayColor)
        case (false, false): AnyShapeStyle(.primary)
        }
    }
}
