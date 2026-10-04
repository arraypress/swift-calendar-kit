//
//  FreeTime.swift
//  CalendarCore
//
//  Gaps, slots and clashes between plain intervals. Touching is not
//  overlapping: a booking ending at 10:00 and one starting at 10:00 do not
//  clash unless there is a buffer between them.
//

import Foundation

extension Timetable {

    /// The gaps inside some windows that nothing busy covers.
    ///
    /// - Parameters:
    ///   - buffer: kept clear either side of each busy interval.
    ///   - minimumLength: gaps shorter than this are dropped.
    public static func freeTime(in windows: [DateInterval], busy: [DateInterval], buffer: TimeInterval = 0,
                                minimumLength: TimeInterval = 0) -> [DateInterval] {
        FreeTime.gaps(in: windows, busy: busy, buffer: buffer, minimumLength: minimumLength)
    }

    /// Bookable slots of a fixed length: one every `step` from the start of
    /// each window, kept when it fits inside the window and clashes with
    /// nothing. `step` defaults to the slot's own length.
    public static func slots(length: TimeInterval, every step: TimeInterval? = nil, in windows: [DateInterval],
                             busy: [DateInterval] = [], buffer: TimeInterval = 0) -> [DateInterval] {
        FreeTime.slots(length: length, every: step ?? length, in: windows, busy: busy, buffer: buffer)
    }

    /// The busy intervals a candidate overlaps, as indices. Touching is not
    /// overlapping, unless a buffer closes the gap.
    public static func clashes(_ candidate: DateInterval, with busy: [DateInterval], buffer: TimeInterval = 0) -> [Int] {
        FreeTime.clashes(candidate, with: busy, buffer: buffer)
    }

    /// Slots across several resources — rooms, staff, tables — each with
    /// its own open windows and bookings. A slot is offered when at least
    /// `minimumFree` resources are free for all of it. A resource with no
    /// windows is never free.
    public static func slots<R: Hashable & Sendable>(
        length: TimeInterval, every step: TimeInterval? = nil, resources: [R],
        windows: [R: [DateInterval]], busy: [R: [DateInterval]] = [:], buffer: TimeInterval = 0, minimumFree: Int = 1
    ) -> [ResourceSlot<R>] {
        FreeTime.resourceSlots(length: length, every: step ?? length, resources: resources, windows: windows,
                               busy: busy, buffer: buffer, minimumFree: minimumFree)
    }

    /// The timed events that clash: overlapping another, or closer to one
    /// than `buffer`, among events `sameGroup` says compete — the same room,
    /// the same person. All-day events are left out.
    public static func conflicts<E: CalendarEvent>(_ events: [E], buffer: TimeInterval = 0,
                                                   sameGroup: (E, E) -> Bool = { _, _ in true }) -> Set<E.ID> {
        FreeTime.conflicts(events, buffer: buffer, sameGroup: sameGroup)
    }

    /// The resources free for the whole of a candidate booking, in the order given.
    public static func freeResources<R: Hashable & Sendable>(
        for candidate: DateInterval, resources: [R], windows: [R: [DateInterval]], busy: [R: [DateInterval]] = [:],
        buffer: TimeInterval = 0
    ) -> [R] {
        FreeTime.freeResources(for: candidate, resources: resources, windows: windows, busy: busy, buffer: buffer)
    }
}

enum FreeTime {

    static func overlaps(_ a: DateInterval, _ b: DateInterval) -> Bool {
        a.start < b.end && b.start < a.end
    }

    /// Busy time grown by the buffer on both sides, sorted and merged.
    static func blocked(_ busy: [DateInterval], buffer: TimeInterval) -> [DateInterval] {
        let grown = busy.map { DateInterval(start: $0.start.addingTimeInterval(-buffer), end: $0.end.addingTimeInterval(buffer)) }
        return merged(grown)
    }

    /// Overlapping or touching intervals joined into one.
    static func merged(_ intervals: [DateInterval]) -> [DateInterval] {
        var result: [DateInterval] = []
        for interval in intervals.sorted(by: { $0.start < $1.start }) {
            if let last = result.last, interval.start <= last.end {
                result[result.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                result.append(interval)
            }
        }
        return result
    }

    static func gaps(in windows: [DateInterval], busy: [DateInterval], buffer: TimeInterval, minimumLength: TimeInterval) -> [DateInterval] {
        let blocked = blocked(busy, buffer: buffer)
        return merged(windows).flatMap { window -> [DateInterval] in
            var gaps: [DateInterval] = []
            var cursor = window.start
            for block in blocked where block.end > window.start && block.start < window.end {
                if block.start > cursor { gaps.append(DateInterval(start: cursor, end: block.start)) }
                cursor = max(cursor, block.end)
            }
            if cursor < window.end { gaps.append(DateInterval(start: cursor, end: window.end)) }
            return gaps.filter { $0.duration > 0 && $0.duration >= minimumLength }
        }
    }

    static func clashes(_ candidate: DateInterval, with busy: [DateInterval], buffer: TimeInterval) -> [Int] {
        busy.indices.filter { index in
            let grown = DateInterval(start: busy[index].start.addingTimeInterval(-buffer), end: busy[index].end.addingTimeInterval(buffer))
            return overlaps(candidate, grown)
        }
    }

    /// Slots of a fixed length, stepped from the start of each window, that
    /// fit inside it and clash with nothing.
    static func slots(length: TimeInterval, every step: TimeInterval, in windows: [DateInterval], busy: [DateInterval], buffer: TimeInterval) -> [DateInterval] {
        guard length > 0, step > 0 else { return [] }
        let blocked = blocked(busy, buffer: buffer)
        return windows.sorted { $0.start < $1.start }.flatMap { window -> [DateInterval] in
            stride(from: window.start, through: window.end.addingTimeInterval(-length), by: step).compactMap { start in
                let slot = DateInterval(start: start, duration: length)
                return blocked.contains(where: { overlaps(slot, $0) }) ? nil : slot
            }
        }
    }

    static func resourceSlots<R: Hashable & Sendable>(
        length: TimeInterval, every step: TimeInterval, resources: [R],
        windows: [R: [DateInterval]], busy: [R: [DateInterval]], buffer: TimeInterval, minimumFree: Int
    ) -> [ResourceSlot<R>] {
        var free: [DateInterval: [R]] = [:]
        for resource in resources {
            for slot in slots(length: length, every: step, in: windows[resource] ?? [], busy: busy[resource] ?? [], buffer: buffer) {
                free[slot, default: []].append(resource)
            }
        }
        return free.filter { $0.value.count >= max(minimumFree, 1) }
            .map { ResourceSlot(interval: $0.key, free: $0.value) }
            .sorted { $0.interval.start < $1.interval.start }
    }

    static func freeResources<R: Hashable & Sendable>(
        for candidate: DateInterval, resources: [R], windows: [R: [DateInterval]], busy: [R: [DateInterval]], buffer: TimeInterval
    ) -> [R] {
        resources.filter { resource in
            let open = merged(windows[resource] ?? []).contains { $0.start <= candidate.start && candidate.end <= $0.end }
            return open && clashes(candidate, with: busy[resource] ?? [], buffer: buffer).isEmpty
        }
    }

    /// Timed events that overlap another, or come within `buffer` of one, in
    /// the same group. Sorted by start, each is compared with those still
    /// open, so it stays close to linear for a real diary.
    static func conflicts<E: CalendarEvent>(_ events: [E], buffer: TimeInterval, sameGroup: (E, E) -> Bool) -> Set<E.ID> {
        let timed = events.filter { !$0.isAllDay }.sorted { $0.start < $1.start }
        var flagged = Set<E.ID>()
        var open: [E] = []
        for event in timed {
            open.removeAll { $0.end.addingTimeInterval(buffer) <= event.start }
            for other in open where sameGroup(other, event) && event.start < other.end.addingTimeInterval(buffer) {
                flagged.insert(other.id)
                flagged.insert(event.id)
            }
            open.append(event)
        }
        return flagged
    }
}
