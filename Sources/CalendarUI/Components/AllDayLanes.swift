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
    @ScaledMetric(relativeTo: .caption) private var textScale: CGFloat = 1
    let days: [Date]
    let events: [Event]
    let calendar: Calendar
    var secondZone = false
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
                    .padding(.trailing, 6)
                    .frame(width: style.labelColumnWidth(secondZone: secondZone), alignment: .trailing)
                    .padding(.top, 4)
                GeometryReader { geometry in
                    let column = geometry.size.width / CGFloat(max(days.count, 1))
                    let bar = barHeight
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
                .frame(height: rows * barHeight)
            }
            .padding(.vertical, 4)
        }
    }

    /// The style's bar height, grown with larger text so a title still fits.
    private var barHeight: CGFloat { style.allDayBarHeight * max(textScale, 1) }
}
