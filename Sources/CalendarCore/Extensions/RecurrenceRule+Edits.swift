//
//  RecurrenceRule+Edits.swift
//  CalendarCore
//

import Foundation

extension RecurrenceRule {

    /// This rule without the occurrence on `date`'s day — "delete this
    /// event" and the first half of "move this event".
    public func skipping(_ date: Date) -> RecurrenceRule {
        Edits.rule(self, count: count, until: until, exceptions: exceptions.union([date]))
    }

    /// This rule ending before `date` — "delete this and following". Keeps
    /// everything up to the occurrence before; a count becomes an end date.
    public func ending(before date: Date) -> RecurrenceRule {
        Edits.rule(self, count: nil, until: date.addingTimeInterval(-1), exceptions: exceptions)
    }

    /// This rule with no count or end — for the new series "this and
    /// following" starts, which should not inherit a count of the old one's.
    public var unending: RecurrenceRule {
        Edits.rule(self, count: nil, until: nil, exceptions: exceptions)
    }
}
