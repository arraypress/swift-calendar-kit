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
                .accessibilityLabel(Text(calendar.format(day) { $0.weekday(.wide).day().month(.wide) }))
                .accessibilityValue(Text(marker(day) == nil ? "" : String(localized: "has events", bundle: .module)))
                .accessibilityAddTraits(calendar.isDate(day, inSameDayAs: selection) ? .isSelected : [])
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
