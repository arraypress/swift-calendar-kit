//
//  NightlyRates.swift
//  CalendarCore
//

import Foundation

/// What a night costs: a base rate, a weekend rate, seasons on top, discounts
/// for longer stays and a fee per stay.
///
/// Amounts are plain `Decimal`s in whatever currency the caller works in, and
/// are never rounded here — round once, for display, at the end.
public struct NightlyRates: Sendable, Hashable, Codable {

    /// The usual price of a night.
    public var nightly: Decimal

    /// The price of a weekend night, if it differs.
    public var weekendNightly: Decimal?

    /// Which nights count as the weekend, named by the day they start on.
    /// Friday and Saturday nights by default — Sunday night is a school night.
    public var weekendNights: Set<Locale.Weekday>

    /// Dated rates. Where seasons overlap, the later one in the list wins, so
    /// a Christmas week can sit on top of a winter season.
    public var seasons: [Season]

    /// Discounts for longer stays. The biggest one the stay qualifies for applies.
    public var discounts: [StayDiscount]

    /// Charged once per stay, such as cleaning.
    public var perStayFee: Decimal

    /// Rates for a place.
    public init(nightly: Decimal, weekendNightly: Decimal? = nil, weekendNights: Set<Locale.Weekday> = [.friday, .saturday],
                seasons: [Season] = [], discounts: [StayDiscount] = [], perStayFee: Decimal = 0) {
        self.nightly = nightly
        self.weekendNightly = weekendNightly
        self.weekendNights = weekendNights
        self.seasons = seasons
        self.discounts = discounts
        self.perStayFee = perStayFee
    }
}

/// A run of nights with their own price, and perhaps their own minimum stay.
public struct Season: Sendable, Hashable, Codable {

    /// What to call it on a quote: "Summer", "Christmas".
    public var name: String

    /// The first night of the season.
    public var from: CalendarDay

    /// The last night of the season, inclusive.
    public var through: CalendarDay

    /// The price of a night in the season.
    public var nightly: Decimal

    /// The price of a weekend night in the season, if it differs.
    public var weekendNightly: Decimal?

    /// The fewest nights for a stay that checks in during the season.
    public var minimumNights: Int?

    /// A season.
    public init(name: String, from: CalendarDay, through: CalendarDay, nightly: Decimal,
                weekendNightly: Decimal? = nil, minimumNights: Int? = nil) {
        self.name = name
        self.from = from
        self.through = through
        self.nightly = nightly
        self.weekendNightly = weekendNightly
        self.minimumNights = minimumNights
    }
}

/// Money off for staying at least so many nights.
public struct StayDiscount: Sendable, Hashable, Codable {

    /// The nights needed to qualify.
    public var minimumNights: Int

    /// The percentage off the nights (not the per-stay fee): 10 is 10%.
    public var percent: Decimal

    /// A discount.
    public init(minimumNights: Int, percent: Decimal) {
        self.minimumNights = minimumNights
        self.percent = percent
    }
}

/// A priced stay, night by night.
public struct StayQuote: Sendable, Hashable {

    /// Each night and what it costs.
    public let nights: [NightPrice]

    /// The nights added up.
    public let subtotal: Decimal

    /// The discount applied, if any.
    public let discount: StayDiscount?

    /// The amount the discount takes off.
    public let discountAmount: Decimal

    /// The per-stay fee.
    public let perStayFee: Decimal

    /// What the guest pays.
    public let total: Decimal
}

/// One night on a ``StayQuote``.
public struct NightPrice: Sendable, Hashable {

    /// The night, named by the day it starts on.
    public let night: CalendarDay

    /// What it costs.
    public let amount: Decimal

    /// The season it fell in, if any.
    public let season: String?

    /// Whether it was priced as a weekend night.
    public let isWeekend: Bool
}
