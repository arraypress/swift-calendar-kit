//
//  AllDayLanes.swift
//  CalendarUI
//
//  All-day events as bars in lanes across a row of days.
//

import SwiftUI

/// All-day events as bars in lanes across the days, with "+N" where they overflow.
struct AllDayLanes<Event: CalendarEvent, Tile: View>: View {

    @Environment(\.calendarStyle) private var style
    let days: [Date]
    let events: [Event]
    let calendar: Calendar
    let tile: (Event) -> Tile
    let onSelect: ((Event) -> Void)?

    var body: some View {
        let layout = Timetable.lanes(events.filter(\.isAllDay), across: days, calendar: calendar,
                                     maximumLanes: style.maximumAllDayLanes)
        let overflow = layout.hidden.contains { $0 > 0 }
        let rows = CGFloat(layout.laneCount + (overflow ? 1 : 0))
        if rows > 0 {
            HStack(alignment: .top, spacing: 0) {
                Text("all-day", bundle: .module)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: style.hourLabelWidth, alignment: .trailing)
                    .padding(.trailing, 6)
                    .padding(.top, 4)
                GeometryReader { geometry in
                    let column = geometry.size.width / CGFloat(max(days.count, 1))
                    let bar = style.allDayBarHeight
                    ZStack(alignment: .topLeading) {
                        ForEach(layout.bars) { placed in
                            tile(placed.event)
                                .frame(width: column * CGFloat(placed.length) - 3, height: bar - 2)
                                .selectable(placed.event, calendar: calendar, onSelect: onSelect)
                                .modifier(DayDrag(event: placed.event, columnWidth: column, calendar: calendar))
                                .padding(.leading, column * CGFloat(placed.firstDay) + 2)
                                .padding(.top, CGFloat(placed.lane) * bar)
                        }
                        ForEach(Array(layout.hidden.enumerated()), id: \.offset) { index, count in
                            if count > 0 {
                                Text("+\(count)", bundle: .module)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .offset(x: column * CGFloat(index) + 6, y: CGFloat(layout.laneCount) * bar + 2)
                            }
                        }
                    }
                }
                .frame(height: rows * style.allDayBarHeight)
            }
            .padding(.vertical, 4)
        }
    }
}
