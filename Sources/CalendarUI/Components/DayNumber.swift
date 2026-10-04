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
    @ScaledMetric(relativeTo: .callout) private var size: CGFloat = 30

    var body: some View {
        let today = calendar.isToday(day)
        Text(calendar.dayNumber(day))
            .font(font.weight(today || isSelected ? .semibold : .regular))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(foreground(today: today))
            .frame(width: min(size, 44), height: min(size, 44))  // grows with the text, but a week of them still fits a phone
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
