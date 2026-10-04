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

/// The hour labels, each centred on its line.
private struct HourLabels: View {

    @Environment(\.calendarStyle) private var style
    let day: Date
    let calendar: Calendar
    var secondZone: TimeZone? = nil

    var body: some View {
        let marks = Timetable.hourMarks(on: day, calendar: calendar)
        let height = height(of: day)
        let other = secondZone.map { zone -> Calendar in
            var copy = calendar
            copy.timeZone = zone
            return copy
        }
        ZStack(alignment: .topTrailing) {
            Color.clear
            ForEach(marks) { mark in
                HStack(spacing: 4) {
                    if let other {
                        Text(mark.hour == 0 ? abbreviation(other.timeZone) : other.hourLabel(mark.date))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    Text(mark.hour == 0 ? (other == nil ? "" : abbreviation(calendar.timeZone)) : calendar.hourLabel(mark.date))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: other == nil ? 0 : style.hourLabelWidth * 0.8, alignment: .trailing)
                }
                    .font(.caption2)
                    .padding(.trailing, 6)
                    .padding(.top, max(mark.position * height - 7, 0))  // padding, not offset: scrollTo needs the real frame
                    .id(mark.hour)
            }
        }
        .frame(height: height)
    }

    private func height(of day: Date) -> CGFloat {
        CGFloat(calendar.dateInterval(of: .day, for: day)!.duration / 3600) * style.hourHeight
    }

    /// "BST", or the zone's name when it has no short form here.
    private func abbreviation(_ zone: TimeZone) -> String {
        zone.abbreviation(for: day) ?? zone.identifier
    }
}

/// One day's lines and events, and — with editing on — the drags that move,
/// resize and create them.
private struct DayColumn<Event: CalendarEvent, Tile: View>: View {

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

/// Moving a timed tile by dragging it, and resizing it by its bottom edge.
/// The tile follows the pointer in snapped steps and shows its new time;
/// letting go hands the new interval to the editor.
private struct TimedDrag<Event: CalendarEvent>: ViewModifier {

    @Environment(\.calendarEditor) private var editor
    let event: Event
    let height: CGFloat
    let columnWidth: CGFloat
    let days: ClosedRange<Int>
    let secondsPerPoint: TimeInterval
    let calendar: Calendar

    @State private var move: CGSize?
    @State private var stretch: CGFloat?

    func body(content: Content) -> some View {
        let original = DateInterval(start: event.start, end: max(event.end, event.start))
        let snap = editor?.snap ?? 900
        let snapPoints = CGFloat(snap / secondsPerPoint)
        let dayStep = move.map { min(max(Int(($0.width / max(columnWidth, 1)).rounded()), days.lowerBound), days.upperBound) } ?? 0
        let rawSeconds = TimeInterval(move?.height ?? 0) * secondsPerPoint
        let preview = move.map { _ in Timetable.moved(original, days: dayStep, by: rawSeconds, snap: snap, calendar: calendar) }
        let resized = stretch.map { Timetable.resized(original, end: original.end.addingTimeInterval(TimeInterval($0) * secondsPerPoint),
                                                      snap: snap, calendar: calendar) }
        let canEdit = editor?.canReschedule == true

        content
            .frame(height: max(height + (resized.map { CGFloat(($0.duration - original.duration) / secondsPerPoint) } ?? 0), snapPoints, 4),
                   alignment: .top)
            .overlay(alignment: .topTrailing) {
                if let shown = preview ?? resized {
                    Text(calendar.timeRange(shown.start, shown.end))
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(.regularMaterial, in: Capsule())
                        .offset(y: -18)
                        .fixedSize()
                }
            }
            .overlay(alignment: .bottom) {
                if canEdit, editor?.isSelected(event.id) == true {
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: 28, height: 5)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle().inset(by: -6))
                        .editDrag(in: .global) { step in
                            stretch = step.translation.height
                            editor?.draggingID = AnyHashable(event.id)
                        } onEnded: { _ in
                            if let resized, resized != original { editor?.reschedule(event, resized) }
                            stretch = nil
                            editor?.draggingID = nil
                        }
                        .resizeCursor(vertical: true)
                }
            }
            .offset(x: CGFloat(dayStep) * columnWidth, y: verticalShift(preview, from: original))
            .opacity(move == nil ? 1 : 0.9)
            .shadow(color: .black.opacity(move == nil ? 0 : 0.25), radius: move == nil ? 0 : 6, y: 3)
            .editDrag(enabled: canEdit) { step in
                move = step.translation
                editor?.draggingID = AnyHashable(event.id)
                if editor?.isSelected(event.id) == false { editor?.select(event, id: AnyHashable(event.id)) }
            } onEnded: { _ in
                if let preview, preview != original { editor?.reschedule(event, preview) }
                move = nil
                editor?.draggingID = nil
            }
    }

    /// How far down the previewed start sits from the original, in points.
    private func verticalShift(_ preview: DateInterval?, from original: DateInterval) -> CGFloat {
        guard let preview else { return 0 }
        return CGFloat((timeOfDay(preview.start) - timeOfDay(original.start)) / secondsPerPoint)
    }

    /// Seconds since the start of an instant's day, so a move across days
    /// previews only its change in time of day vertically.
    private func timeOfDay(_ date: Date) -> TimeInterval {
        date.timeIntervalSince(calendar.startOfDay(for: date))
    }
}

/// A line at the current time, kept current.
private struct NowLine: View {

    @Environment(\.calendarStyle) private var style
    let day: DateInterval
    let height: CGFloat

    var body: some View {
        TimelineView(.everyMinute) { context in
            if day.contains(context.date) {
                HStack(spacing: 0) {
                    Circle().fill(style.todayColor).frame(width: 7, height: 7)
                    Rectangle().fill(style.todayColor).frame(height: 1.5)
                }
                .offset(x: -3.5, y: context.date.timeIntervalSince(day.start) / day.duration * height - 3.5)
            }
        }
        .allowsHitTesting(false)
    }
}

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
