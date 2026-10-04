//
//  StayRecord.swift
//  CalendarCore
//

import Foundation

/// A booked stay with its money: what it earned, what the channel took, and
/// when it was booked — what rental metrics are worked out from.
public struct StayRecord: Sendable, Hashable, Codable {

    /// The nights.
    public var stay: Stay

    /// What the whole stay earned, before any channel fee, in the caller's currency.
    public var amount: Decimal

    /// What the channel it came through takes, if any.
    public var fee: ChannelFee?

    /// The day it was booked, for lead time; nil if unknown.
    public var bookedOn: CalendarDay?

    /// A record of a stay.
    public init(stay: Stay, amount: Decimal, fee: ChannelFee? = nil, bookedOn: CalendarDay? = nil) {
        self.stay = stay
        self.amount = amount
        self.fee = fee
        self.bookedOn = bookedOn
    }
}

/// What a booking channel deducts: a flat amount per booking plus a share of it.
///
/// Supplied by the app, never built in: platforms' rates differ by country,
/// listing and year, and a table of them here would quietly go stale.
public struct ChannelFee: Sendable, Hashable, Codable {

    /// Taken once per booking.
    public var flat: Decimal

    /// Taken as a share of the amount: 15 is 15%.
    public var percent: Decimal

    /// A fee.
    public init(flat: Decimal = 0, percent: Decimal = 0) {
        self.flat = flat
        self.percent = percent
    }
}
