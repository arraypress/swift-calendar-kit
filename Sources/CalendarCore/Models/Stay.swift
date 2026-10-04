//
//  Stay.swift
//  CalendarCore
//

import Foundation

/// A booking counted in nights: check in one day, check out a later one.
///
/// A stay occupies the nights from `checkIn` up to but not including
/// `checkOut`, so one guest can leave on the morning another arrives.
public struct Stay: Sendable, Hashable, Codable {

    /// The day the guest arrives.
    public let checkIn: CalendarDay

    /// The day the guest leaves.
    public let checkOut: CalendarDay

    /// A stay. Not checked here, so a picker can hold a half-made one;
    /// ``Timetable/check(_:against:rules:rates:)`` reports a check-out that
    /// is not after the check-in as ``StayCheck/invalidDates``.
    public init(checkIn: CalendarDay, checkOut: CalendarDay) {
        self.checkIn = checkIn
        self.checkOut = checkOut
    }

    /// A stay of a number of nights.
    public init(checkIn: CalendarDay, nights: Int) {
        self.init(checkIn: checkIn, checkOut: checkIn.adding(days: nights))
    }
}

/// The house rules a stay must meet.
public struct StayRules: Sendable, Hashable, Codable {

    /// The fewest nights bookable. A season's own minimum can raise it.
    public var minimumNights: Int

    /// The most nights bookable, if there is a limit.
    public var maximumNights: Int?

    /// Whether a guest may arrive on the day the last one leaves. Turn it
    /// off when the place needs a clear day for cleaning.
    public var sameDayTurnover: Bool

    /// Rules for a stay.
    public init(minimumNights: Int = 1, maximumNights: Int? = nil, sameDayTurnover: Bool = true) {
        self.minimumNights = minimumNights
        self.maximumNights = maximumNights
        self.sameDayTurnover = sameDayTurnover
    }
}
