//
//  Timeline.swift
//  CalendarUI
//
//  Hour labels down the side, one column per day, timed events placed by
//  CalendarCore. Shared by the day and week views.
//

import SwiftUI

struct Timeline<Event: CalendarEvent, Tile: View>: View {

    @Environment(\.calendarStyle) private var style
    @Environment(\.calendarEditor) private var editor
    @Environment(\.conflictRule) private var conflictRule
    let days: [Date]
    let events: [Event]
    let calendar: Calendar
    var selectedDay: Date? = nil
    var hours: OpeningHours? = nil
    var secondZone: TimeZone? = nil
    let tile: (Event) -> Tile
    let onSelect: ((Event) -> Void)?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    HourLabels(day: days.first ?? .now, calendar: calendar, secondZone: secondZone)
                        .frame(width: style.hourLabelWidth * (secondZone == nil ? 1 : 1.8))
                    ForEach(Array(days.enumerated()), id: \.element) { index, day in
                        DayColumn(day: day, index: index, dayCount: days.count, events: events, calendar: calendar,
                                  isSelectedDay: days.count > 1 && selectedDay.map { calendar.isDate($0, inSameDayAs: day) } == true,
                                  hours: hours, tile: tile, onSelect: onSelect)
                            .zIndex(events.contains { editor?.isDragging($0.id) == true && calendar.isDate($0.start, inSameDayAs: day) } ? 1 : 0)
                    }
                }
                .padding(.vertical, 10)
                .environment(\.conflicts, ConflictSet(ids: conflictRule?.find(events) ?? []))
            }
            .onAppear {
                editor?.calendar = calendar
                DispatchQueue.main.async { proxy.scrollTo(style.firstVisibleHour, anchor: .top) }
            }
        }
    }
}
