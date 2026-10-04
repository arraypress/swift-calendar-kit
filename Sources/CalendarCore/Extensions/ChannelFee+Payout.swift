//
//  ChannelFee+Payout.swift
//  CalendarCore
//

import Foundation

extension ChannelFee {

    /// What the channel takes from an amount: the flat part plus its share,
    /// never more than the amount.
    public func fee(on amount: Decimal) -> Decimal {
        Metrics.fee(on: amount, self)
    }

    /// What reaches the host from an amount.
    public func payout(from amount: Decimal) -> Decimal {
        amount - fee(on: amount)
    }
}
