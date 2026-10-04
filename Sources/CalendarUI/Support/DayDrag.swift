//
//  DayDrag.swift
//  CalendarUI
//
//  Moving an all-day bar by whole days.
//

import SwiftUI

/// Moving an all-day bar by whole days.
struct DayDrag<Event: CalendarEvent>: ViewModifier {

    @Environment(\.calendarEditor) private var editor
    let event: Event
    let columnWidth: CGFloat
    let calendar: Calendar

    @State private var offset: CGFloat?

    func body(content: Content) -> some View {
        let days = offset.map { Int(($0 / max(columnWidth, 1)).rounded()) } ?? 0
        content
            .offset(x: CGFloat(days) * columnWidth)
            .shadow(color: .black.opacity(offset == nil ? 0 : 0.25), radius: offset == nil ? 0 : 6, y: 3)
            .zIndex(offset == nil ? 0 : 1)
            .editDrag(enabled: editor?.canReschedule == true) { step in
                offset = step.translation.width
                if editor?.isSelected(event.id) == false { editor?.select(event, id: AnyHashable(event.id)) }
            } onEnded: { _ in
                if days != 0 {
                    editor?.reschedule(event, Timetable.moved(DateInterval(start: event.start, end: max(event.end, event.start)),
                                                              byDays: days, calendar: calendar))
                }
                offset = nil
            }
    }
}
