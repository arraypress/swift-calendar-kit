//
//  Metrics.swift
//  CalendarCore
//
//  Rental figures over a stretch of nights: occupancy, the average nightly
//  rate, revenue per available night, length of stay, lead time, and what
//  the channels took.
//

import Foundation

extension Timetable {

    /// How stays did over the nights from `first` to `last`, inclusive.
    ///
    /// - Parameters:
    ///   - units: how many rentable units the stays share — properties,
    ///     rooms — for the nights available.
    ///   - unavailableNights: unit-nights not offered at all — owner stays,
    ///     repairs — taken off the nights available.
    public static func metrics(_ records: [StayRecord], from first: CalendarDay, through last: CalendarDay,
                               units: Int = 1, unavailableNights: Int = 0) -> StayMetrics {
        Metrics.measure(records, from: first, through: last, units: units, unavailableNights: unavailableNights)
    }
}

enum Metrics {

    static func measure(_ records: [StayRecord], from first: CalendarDay, through last: CalendarDay,
                        units: Int, unavailableNights: Int) -> StayMetrics {
        let nightsInStretch = first <= last ? first.days(until: last) + 1 : 0
        let available = max(nightsInStretch * max(units, 0) - unavailableNights, 0)

        var booked = 0
        var revenue: Decimal = 0
        var fees: Decimal = 0
        for record in records where record.stay.nightCount > 0 {
            let inside = record.stay.nights.filter { first <= $0 && $0 <= last }.count
            guard inside > 0 else { continue }
            let share = Decimal(inside) / Decimal(record.stay.nightCount)
            booked += inside
            revenue += record.amount * share
            fees += (record.fee.map { fee(on: record.amount, $0) } ?? 0) * share
        }

        let arrivals = records.filter { $0.stay.nightCount > 0 && first <= $0.stay.checkIn && $0.stay.checkIn <= last }
        let leads = arrivals.compactMap { record in record.bookedOn.map { $0.days(until: record.stay.checkIn) } }

        return StayMetrics(
            availableNights: available,
            bookedNights: booked,
            occupancy: available > 0 ? Double(booked) / Double(available) : 0,
            revenue: revenue,
            fees: fees,
            payout: revenue - fees,
            averageNightlyRate: booked > 0 ? revenue / Decimal(booked) : nil,
            revenuePerAvailableNight: available > 0 ? revenue / Decimal(available) : nil,
            arrivals: arrivals.count,
            averageStayLength: arrivals.isEmpty ? nil : Double(arrivals.map(\.stay.nightCount).reduce(0, +)) / Double(arrivals.count),
            averageLeadTime: leads.isEmpty ? nil : Double(leads.reduce(0, +)) / Double(leads.count)
        )
    }

    /// The flat part plus the share, never more than the amount itself.
    static func fee(on amount: Decimal, _ fee: ChannelFee) -> Decimal {
        min(fee.flat + amount * fee.percent / 100, amount)
    }
}
