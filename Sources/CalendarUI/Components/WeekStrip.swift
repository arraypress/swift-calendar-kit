//
//  WeekStrip.swift
//  CalendarUI
//

import SwiftUI

/// A row of days with their numbers: tap one to select it, swipe or use the
/// arrows to move a week. A dot marks days with events.
public struct WeekStrip: View {

    @Environment(\.calendarStyle) private var style
    @Binding private var selection: Date
    private let calendar: Calendar
    private let marker: (Date) -> Color?

    /// A strip for the week containing the selection.
    ///
    /// - Parameter marker: the colour of the dot under a day, or `nil` for none.
    public init(selection: Binding<Date>, calendar: Calendar = .current, marker: @escaping (Date) -> Color? = { _ in nil }) {
        _selection = selection
        self.calendar = calendar
        self.marker = marker
    }

    public var body: some View {
        let days = Timetable.week(containing: selection, calendar: calendar)
        let symbols = Timetable.weekdaySymbols(calendar: calendar, style: .narrow)
        HStack(spacing: 0) {
            StepButton(systemImage: "chevron.left") { move(by: -1) }
            ForEach(Array(days.enumerated()), id: \.element) { index, day in
                Button { selection = day } label: {
                    VStack(spacing: 4) {
                        Text(symbols[index])
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        DayNumber(day: day, calendar: calendar,
                                  isSelected: calendar.isDate(day, inSameDayAs: selection))
                        Circle()
                            .fill(marker(day) ?? .clear)
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            StepButton(systemImage: "chevron.right") { move(by: 1) }
        }
        .swipeToStep(move)
    }

    private func move(by weeks: Int) {
        withAnimation(.snappy) {
            selection = calendar.date(byAdding: .weekOfYear, value: weeks, to: selection) ?? selection
        }
    }
}

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

/// A small chevron that steps a period back or forward.
struct StepButton: View {

    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
}
