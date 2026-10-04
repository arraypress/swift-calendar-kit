//
//  Placement.swift
//  CalendarCore
//
//  Side-by-side columns for overlapping timed events, and lanes for bars
//  that run across days.
//

import Foundation

extension Timetable {

    /// A day's all-day events, and its timed events placed on the timeline.
    ///
    /// - Parameter minimumDuration: the shortest an event is drawn — and so
    ///   the space it claims when deciding what overlaps. Pass the time your
    ///   smallest readable tile represents, or 0.
    public static func layout<E: CalendarEvent>(_ events: [E], on date: Date, calendar: Calendar = .current,
                                                minimumDuration: TimeInterval = 0) -> DayLayout<E> {
        Placement.day(events, on: date, in: calendar, minimumDuration: minimumDuration)
    }

    /// Bars for events across a row of consecutive days, stacked in lanes.
    ///
    /// Pass the all-day events for a week view's top strip, or everything for
    /// a month row. With `maximumLanes`, events that do not fit are counted in
    /// ``LaneLayout/hidden`` instead.
    public static func lanes<E: CalendarEvent>(_ events: [E], across days: [Date], calendar: Calendar = .current,
                                               maximumLanes: Int? = nil) -> LaneLayout<E> {
        Placement.lanes(events, across: days, in: calendar, maximumLanes: maximumLanes)
    }
}

enum Placement {

    // MARK: - A day's timeline

    static func day<E: CalendarEvent>(_ events: [E], on date: Date, in calendar: Calendar, minimumDuration: TimeInterval) -> DayLayout<E> {
        let day = EventDays.day(date, in: calendar)
        let touching = events.filter { EventDays.touches($0, day, in: calendar) }
        let allDay = EventDays.ordered(touching.filter(\.isAllDay))
        return DayLayout(day: day, allDay: allDay, timed: timeline(touching.filter { !$0.isAllDay }, in: day, minimumDuration: minimumDuration))
    }

    private struct Item<E> {
        let event: E
        let order: Int
        let start: Date        // clipped to the day
        let end: Date          // clipped to the day
        let drawnEnd: Date     // after the minimum duration
        let blocksUntil: Date  // what overlap is judged against; never equal to start
        var column = 0
        var columns = 1
        var span = 1
    }

    /// Groups events that overlap, directly or through a chain, and gives
    /// each the first column free when it starts. Within a group every event
    /// shares the group's column count, so widths line up.
    static func timeline<E: CalendarEvent>(_ events: [E], in day: DateInterval, minimumDuration: TimeInterval) -> [TimedPlacement<E>] {
        var items = events.enumerated().map { order, event -> Item<E> in
            let start = max(event.start, day.start)
            let end = max(min(event.end, day.end), start)
            let drawnEnd = min(max(end, start.addingTimeInterval(minimumDuration)), day.end)
            return Item(event: event, order: order, start: start, end: end, drawnEnd: drawnEnd,
                        blocksUntil: drawnEnd > start ? drawnEnd : start.addingTimeInterval(1))
        }
        items.sort { a, b in
            if a.start != b.start { return a.start < b.start }
            if a.blocksUntil != b.blocksUntil { return a.blocksUntil > b.blocksUntil }
            return a.order < b.order
        }

        var groupStart = 0
        var groupEnd = Date.distantPast
        for index in items.indices {
            if index > groupStart && items[index].start >= groupEnd {
                arrange(&items, groupStart..<index)
                groupStart = index
            }
            groupEnd = max(groupEnd, items[index].blocksUntil)
        }
        if !items.isEmpty { arrange(&items, groupStart..<items.count) }

        return items.sorted { $0.order < $1.order }.map { item in
            TimedPlacement(
                event: item.event, start: item.start, end: item.end,
                column: item.column, columns: item.columns, span: item.span,
                top: item.start.timeIntervalSince(day.start) / day.duration,
                height: item.drawnEnd.timeIntervalSince(item.start) / day.duration,
                continuesFromPreviousDay: item.event.start < day.start,
                continuesToNextDay: item.event.end > day.end
            )
        }
    }

    private static func arrange<E>(_ items: inout [Item<E>], _ group: Range<Int>) {
        var columnEnds: [Date] = []
        for index in group {
            if let free = columnEnds.firstIndex(where: { $0 <= items[index].start }) {
                items[index].column = free
                columnEnds[free] = items[index].blocksUntil
            } else {
                items[index].column = columnEnds.count
                columnEnds.append(items[index].blocksUntil)
            }
        }
        for index in group {
            items[index].columns = columnEnds.count
            var span = 1
            for column in (items[index].column + 1)..<max(columnEnds.count, items[index].column + 1) {
                let blocked = group.contains { other in
                    items[other].column == column
                        && items[other].start < items[index].blocksUntil
                        && items[index].start < items[other].blocksUntil
                }
                if blocked { break }
                span += 1
            }
            items[index].span = span
        }
    }

    // MARK: - Bars across days

    private struct Candidate<E> {
        let event: E
        let order: Int
        let first: Int
        let last: Int
        let start: Date
        let end: Date
    }

    /// Lays bars across consecutive days. Longer bars claim lanes first so a
    /// week-long trip sits on top rather than being pushed down by a
    /// one-day event that happens to start the same morning.
    static func lanes<E: CalendarEvent>(_ events: [E], across days: [Date], in calendar: Calendar, maximumLanes: Int?) -> LaneLayout<E> {
        guard let firstDay = days.first, let lastDay = days.last else {
            return LaneLayout(bars: [], laneCount: 0, hidden: [])
        }
        let intervals = days.map { EventDays.day($0, in: calendar) }
        let row = DateInterval(start: EventDays.day(firstDay, in: calendar).start, end: EventDays.day(lastDay, in: calendar).end)

        let candidates = events.enumerated().compactMap { order, event -> Candidate<E>? in
            let covered = intervals.indices.filter { EventDays.touches(event, intervals[$0], in: calendar) }
            guard let first = covered.first, let last = covered.last else { return nil }
            let (start, end) = EventDays.coverage(of: event, in: calendar)
            return Candidate(event: event, order: order, first: first, last: last, start: start, end: end)
        }.sorted { a, b in
            if a.first != b.first { return a.first < b.first }
            if a.last - a.first != b.last - b.first { return a.last - a.first > b.last - b.first }
            if a.start != b.start { return a.start < b.start }
            return a.order < b.order
        }

        var laneEnds: [Int] = []
        var bars: [LaneBar<E>] = []
        var hidden = Array(repeating: 0, count: days.count)
        for candidate in candidates {
            let lane = laneEnds.firstIndex { $0 < candidate.first } ?? laneEnds.count
            if let limit = maximumLanes, lane >= limit {
                for day in candidate.first...candidate.last { hidden[day] += 1 }
                continue
            }
            if lane == laneEnds.count { laneEnds.append(candidate.last) } else { laneEnds[lane] = candidate.last }
            bars.append(LaneBar(event: candidate.event, lane: lane, firstDay: candidate.first, lastDay: candidate.last,
                                continuesBefore: candidate.start < row.start, continuesAfter: candidate.end > row.end))
        }
        return LaneLayout(bars: bars, laneCount: laneEnds.count, hidden: hidden)
    }
}
