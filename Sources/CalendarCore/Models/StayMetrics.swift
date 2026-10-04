//
//  StayMetrics.swift
//  CalendarCore
//

import Foundation

/// How a rental did over a stretch of nights — the figures a host or a
/// property manager reports.
///
/// Money is counted night by night: a stay's amount is spread evenly over
/// its nights, so a stay that runs across the end of a month earns each month
/// only its own nights. Counts of stays — bookings, length, lead time — are of
/// the stays that check in within the stretch.
public struct StayMetrics: Sendable, Hashable {

    /// Nights that could have been let: the stretch's nights for every unit,
    /// less any not offered.
    public let availableNights: Int

    /// Nights let in the stretch. A double booking counts twice.
    public let bookedNights: Int

    /// Booked nights over available ones, 0 to 1 (above 1 only when double-booked).
    public let occupancy: Double

    /// What the stretch's nights earned, before channel fees.
    public let revenue: Decimal

    /// What the channels took from those nights.
    public let fees: Decimal

    /// Revenue less fees.
    public let payout: Decimal

    /// Revenue per booked night — the average daily rate. Nil with no nights booked.
    public let averageNightlyRate: Decimal?

    /// Revenue per available night — RevPAR. Nil with no nights available.
    public let revenuePerAvailableNight: Decimal?

    /// Stays checking in within the stretch.
    public let arrivals: Int

    /// Their average length in nights. Nil with no arrivals.
    public let averageStayLength: Double?

    /// Their average days from booking to check-in, among those whose booking day is known.
    public let averageLeadTime: Double?
}
