//
//  MonthDrag.swift
//  CalendarUI
//
//  Moving an event in a month grid: columns are days, rows are weeks.
//

import SwiftUI

/// Moving an event in a month grid by dragging it: columns are days, rows are weeks.
struct MonthDrag<Event: CalendarEvent>: ViewModifier {

    @Environment(\.calendarEditor) private var editor
    let event: Event
    let column: CGFloat
    let row: CGFloat
    let calendar: Calendar

    @State private var offset: CGSize?

    func body(content: Content) -> some View {
        let across = offset.map { Int(($0.width / max(column, 1)).rounded()) } ?? 0
        let down = offset.map { Int(($0.height / max(row, 1)).rounded()) } ?? 0
        content
            .offset(x: CGFloat(across) * column, y: CGFloat(down) * row)
            .shadow(color: .black.opacity(offset == nil ? 0 : 0.3), radius: offset == nil ? 0 : 6, y: 3)
            .editDrag(enabled: editor?.canReschedule == true) { step in
                offset = step.translation
                editor?.draggingID = AnyHashable(event.id)
                if editor?.isSelected(event.id) == false { editor?.select(event, id: AnyHashable(event.id)) }
            } onEnded: { _ in
                let days = across + down * 7
                if days != 0 {
                    editor?.reschedule(event, Timetable.moved(DateInterval(start: event.start, end: max(event.end, event.start)),
                                                              byDays: days, calendar: calendar))
                }
                offset = nil
                editor?.draggingID = nil
            }
    }
}
