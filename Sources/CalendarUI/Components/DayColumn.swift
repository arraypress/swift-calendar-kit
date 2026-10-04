//
//  DayColumn.swift
//  CalendarUI
//
//  One day's column on a timeline: its lines, closed hours, events, and the sweep that creates one.
//

import SwiftUI

/// One day's lines and events, and — with editing on — the drags that move,
/// resize and create them.
struct DayColumn<Event: CalendarEvent, Tile: View>: View {

    @Environment(\.calendarStyle) private var style
    @Environment(\.calendarEditor) private var editor
    let day: Date
    let index: Int
    let dayCount: Int
    let events: [Event]
    let calendar: Calendar
    let isSelectedDay: Bool
    let hours: OpeningHours?
    let tile: (Event) -> Tile
    let onSelect: ((Event) -> Void)?

    /// The stretch being swept out on empty time, as top and bottom offsets.
    @State private var sweep: (from: CGFloat, to: CGFloat)?

    var body: some View {
        let layout = Timetable.layout(events, on: day, calendar: calendar, minimumDuration: style.minimumEventDuration)
        let height = CGFloat(layout.day.duration / 3600) * style.hourHeight
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(isSelectedDay ? Color.accentColor.opacity(0.05) : Color.clear)
                    .contentShape(Rectangle())
                    #if os(tvOS)
                    .onTapGesture { editor?.select(nil, id: nil) }
                    #else
                    .onTapGesture(coordinateSpace: .local) { point in
                        editor?.select(nil, id: nil)
                        let seconds = TimeInterval(min(max(point.y, 0), height) / height) * layout.day.duration
                        let snap = editor?.snap ?? 900
                        editor?.pasteTarget = PasteTarget(date: layout.day.start.addingTimeInterval((seconds / snap).rounded(.down) * snap), isDay: false)
                    }
                    #endif
                    .editDrag(enabled: editor?.canCreate == true) { step in
                        sweep = (step.start.y, step.start.y + step.translation.height)
                    } onEnded: { step in
                        sweep = nil
                        let seconds = { (y: CGFloat) in TimeInterval(min(max(y, 0), height) / height) * layout.day.duration }
                        editor?.create(Timetable.span(from: layout.day.start.addingTimeInterval(seconds(step.start.y)),
                                                      to: layout.day.start.addingTimeInterval(seconds(step.start.y + step.translation.height)),
                                                      snap: editor?.snap ?? 900, calendar: calendar))
                    }
                if let hours {
                    ForEach(Array(closed(hours, in: layout.day).enumerated()), id: \.offset) { _, gap in
                        Rectangle()
                            .fill(Color.primary.opacity(0.05))
                            .frame(width: width, height: CGFloat(gap.duration / layout.day.duration) * height)
                            .offset(y: CGFloat(gap.start.timeIntervalSince(layout.day.start) / layout.day.duration) * height)
                            .allowsHitTesting(false)
                    }
                }
                ForEach(Timetable.hourMarks(on: day, calendar: calendar)) { mark in
                    Rectangle()
                        .fill(.separator)
                        .frame(height: 0.5)
                        .offset(y: mark.position * height)
                        .allowsHitTesting(false)
                }
                Rectangle().fill(.separator).frame(width: 0.5, height: height).allowsHitTesting(false)
                if let sweep {
                    let top = max(min(sweep.from, sweep.to), 0), bottom = min(max(sweep.from, sweep.to), height)
                    RoundedRectangle(cornerRadius: style.tileCornerRadius)
                        .fill(Color.accentColor.opacity(0.25))
                        .overlay(RoundedRectangle(cornerRadius: style.tileCornerRadius).strokeBorder(Color.accentColor, lineWidth: 1))
                        .frame(width: max(width - 4, 0), height: max(bottom - top, 4))
                        .offset(x: 2, y: top)
                        .allowsHitTesting(false)
                }
                ForEach(layout.timed) { placement in
                    let tileHeight = max(placement.height * height - 2, 0)
                    tile(placement.event)
                        .conflictOutline(placement.event.id)
                        .selectable(placement.event, calendar: calendar, onSelect: onSelect)
                        .modifier(TimedDrag(event: placement.event, height: tileHeight, columnWidth: width,
                                            days: (-index)...(dayCount - 1 - index), secondsPerPoint: layout.day.duration / height,
                                            calendar: calendar))
                        .frame(width: max(width * placement.width - 3, 0), alignment: .topLeading)
                        .padding(.leading, width * placement.leading + 2)
                        .padding(.top, placement.top * height + 1)
                }
                if calendar.isToday(day) {
                    NowLine(day: layout.day, height: height)
                }
            }
        }
        .frame(height: height)
    }
}

extension DayColumn {

    /// The stretches of the day outside opening hours.
    func closed(_ hours: OpeningHours, in day: DateInterval) -> [DateInterval] {
        let today = CalendarDay(day.start, in: calendar)
        let open = Timetable.openIntervals(hours, from: today, through: today, calendar: calendar)
        return Timetable.freeTime(in: [day], busy: open)
    }
}
