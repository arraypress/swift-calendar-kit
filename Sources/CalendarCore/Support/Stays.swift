//
//  Stays.swift
//  CalendarCore
//
//  Nightly bookings: whether one fits, which days a picker should offer, and
//  what it costs.
//

import Foundation

extension Timetable {

    /// Whether a stay can be booked, and if not the first reason: bad
    /// dates, then too short (a season's minimum counts, judged by the
    /// check-in night), then too long, then clashes.
    public static func check(_ stay: Stay, against booked: [Stay] = [], rules: StayRules = StayRules(),
                             rates: NightlyRates? = nil) -> StayCheck {
        Stays.check(stay, against: booked, rules: rules, rates: rates)
    }

    /// Every night already taken.
    public static func bookedNights(_ stays: [Stay]) -> Set<CalendarDay> {
        Stays.bookedNights(stays)
    }

    /// The days from `first` to `last` a guest could check in for at least
    /// the minimum stay — the enabled days of a check-in picker.
    public static func checkInDays(from first: CalendarDay, through last: CalendarDay, booked: [Stay],
                                   rules: StayRules = StayRules(), rates: NightlyRates? = nil) -> [CalendarDay] {
        Stays.checkInDays(from: first, through: last, booked: booked, rules: rules, rates: rates)
    }

    /// The check-out days that make a bookable stay from a check-in — the
    /// enabled days once the first date is picked. Without a maximum stay it
    /// looks `searchLimit` nights ahead.
    public static func checkOutDays(after checkIn: CalendarDay, booked: [Stay], rules: StayRules = StayRules(),
                                    rates: NightlyRates? = nil, searchLimit: Int = 365) -> [CalendarDay] {
        Stays.checkOutDays(after: checkIn, booked: booked, rules: rules, rates: rates, searchLimit: searchLimit)
    }

    /// A stay priced night by night.
    public static func quote(_ stay: Stay, rates: NightlyRates) -> StayQuote {
        Stays.quote(stay, rates: rates)
    }
}

enum Stays {

    static func nightCount(_ stay: Stay) -> Int {
        stay.checkIn.days(until: stay.checkOut)
    }

    static func nights(of stay: Stay) -> [CalendarDay] {
        let count = nightCount(stay)
        return count > 0 ? (0..<count).map { stay.checkIn.adding(days: $0) } : []
    }

    /// Later seasons win where two overlap, so a Christmas week sits on a winter season.
    static func season(for night: CalendarDay, in rates: NightlyRates) -> Season? {
        rates.seasons.last { $0.from <= night && night <= $0.through }
    }

    static func minimumNights(for checkIn: CalendarDay, rules: StayRules, rates: NightlyRates?) -> Int {
        max(rules.minimumNights, rates?.season(for: checkIn)?.minimumNights ?? 0, 1)
    }

    static func clashes(_ stay: Stay, with booked: [Stay], rules: StayRules) -> [Int] {
        booked.indices.filter { index in
            let other = booked[index]
            guard other.nightCount > 0 else { return false }
            if stay.checkIn < other.checkOut && other.checkIn < stay.checkOut { return true }
            return !rules.sameDayTurnover && (stay.checkIn == other.checkOut || other.checkIn == stay.checkOut)
        }
    }

    static func check(_ stay: Stay, against booked: [Stay], rules: StayRules, rates: NightlyRates?) -> StayCheck {
        guard stay.nightCount > 0 else { return .invalidDates }
        let minimum = minimumNights(for: stay.checkIn, rules: rules, rates: rates)
        if stay.nightCount < minimum { return .tooShort(minimum: minimum) }
        if let maximum = rules.maximumNights, stay.nightCount > maximum { return .tooLong(maximum: maximum) }
        let clashing = clashes(stay, with: booked, rules: rules)
        return clashing.isEmpty ? .available : .clashes(clashing)
    }

    static func bookedNights(_ stays: [Stay]) -> Set<CalendarDay> {
        Set(stays.flatMap(\.nights))
    }

    /// The days a stay of at least the minimum length could begin.
    static func checkInDays(from first: CalendarDay, through last: CalendarDay, booked: [Stay], rules: StayRules, rates: NightlyRates?) -> [CalendarDay] {
        guard first <= last else { return [] }
        return (0...first.days(until: last)).map { first.adding(days: $0) }.filter { day in
            let shortest = Stay(checkIn: day, nights: minimumNights(for: day, rules: rules, rates: rates))
            return check(shortest, against: booked, rules: rules, rates: rates).isAvailable
        }
    }

    /// Once a check-in is picked, the check-out days that make a bookable
    /// stay. Stops at the first clash: every longer stay contains it too.
    static func checkOutDays(after checkIn: CalendarDay, booked: [Stay], rules: StayRules, rates: NightlyRates?, searchLimit: Int) -> [CalendarDay] {
        var days: [CalendarDay] = []
        for nights in 1...max(rules.maximumNights ?? searchLimit, 1) {
            let stay = Stay(checkIn: checkIn, nights: nights)
            switch check(stay, against: booked, rules: rules, rates: rates) {
            case .available: days.append(stay.checkOut)
            case .clashes: return days
            case .tooShort, .tooLong, .invalidDates: continue
            }
        }
        return days
    }

    static func quote(_ stay: Stay, rates: NightlyRates) -> StayQuote {
        let nights = stay.nights.map { night -> NightPrice in
            let season = rates.season(for: night)
            let isWeekend = rates.weekendNights.contains(night.weekday)
            let weekday = season?.nightly ?? rates.nightly
            let weekend = season.map { $0.weekendNightly ?? $0.nightly } ?? rates.weekendNightly ?? rates.nightly
            return NightPrice(night: night, amount: isWeekend ? weekend : weekday, season: season?.name, isWeekend: isWeekend)
        }
        let subtotal = nights.reduce(Decimal(0)) { $0 + $1.amount }
        let discount = rates.discounts.filter { $0.minimumNights <= nights.count }.max { $0.percent < $1.percent }
        let discountAmount = discount.map { subtotal * $0.percent / 100 } ?? 0
        let fee = nights.isEmpty ? 0 : rates.perStayFee
        return StayQuote(nights: nights, subtotal: subtotal, discount: discount, discountAmount: discountAmount,
                         perStayFee: fee, total: subtotal - discountAmount + fee)
    }
}
