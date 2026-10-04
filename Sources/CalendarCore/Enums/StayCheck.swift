//
//  StayCheck.swift
//  CalendarCore
//

import Foundation

/// Whether a stay can be booked, and if not, the first reason why.
public enum StayCheck: Sendable, Hashable {

    /// Bookable.
    case available

    /// The check-out is not after the check-in.
    case invalidDates

    /// Fewer nights than the minimum, which is given.
    case tooShort(minimum: Int)

    /// More nights than the maximum, which is given.
    case tooLong(maximum: Int)

    /// It overlaps existing bookings, given as indices into the list checked against.
    case clashes([Int])
}
