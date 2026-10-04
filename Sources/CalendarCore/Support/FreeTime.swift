//
//  FreeTime.swift
//  CalendarCore
//
//  Gaps, slots and clashes between plain intervals. Touching is not
//  overlapping: a booking ending at 10:00 and one starting at 10:00 do not
//  clash unless there is a buffer between them.
//

import Foundation

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
}
