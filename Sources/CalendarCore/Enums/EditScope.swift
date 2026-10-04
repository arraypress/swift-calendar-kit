//
//  EditScope.swift
//  CalendarCore
//

import Foundation

/// Which occurrences of a repeating event an edit applies to.
public enum EditScope: String, Sendable, Hashable, CaseIterable {

    /// Only the occurrence acted on.
    case thisEvent

    /// The occurrence acted on and every later one.
    case thisAndFollowing

    /// The whole series.
    case allEvents
}
