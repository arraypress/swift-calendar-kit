//
//  StayPicker.swift
//  CalendarUI
//

import SwiftUI

/// Pick a stay the way a booking site does: tap a check-in, then a check-out.
///
/// Days that cannot start a stay are greyed out — taken, too close to the
/// next booking for the minimum stay, or in the past — and once a check-in
/// is chosen, only check-outs that make a bookable stay stay lit. Each date
/// shows that night's price, and the footer totals the stay with seasons,
/// weekend rates, discounts and the per-stay fee.
///
/// `selection` holds the stay as it is being made: `nil` before a check-in,
/// a stay of no nights once a check-in is picked, and the full stay once
/// the check-out is.
public struct StayPicker: View {

    @Environment(\.calendarStyle) private var style
    @Binding private var selection: Stay?
    private let booked: [Stay]
    private let rules: StayRules
    private let rates: NightlyRates?
    private let calendar: Calendar
    private let monthCount: Int
    private let currencyCode: String
    private let today: CalendarDay

    /// A picker over `monthCount` months from this one.
    ///
    /// - Parameters:
    ///   - booked: stays already taken.
    ///   - rates: prices; leave out to show dates only.
    ///   - currencyCode: how prices are written, such as `"GBP"`.
    public init(selection: Binding<Stay?>, booked: [Stay], rules: StayRules = StayRules(), rates: NightlyRates? = nil,
                calendar: Calendar = .current, monthCount: Int = 12,
                currencyCode: String = Locale.current.currency?.identifier ?? "USD", today: Date = .now) {
        _selection = selection
        self.booked = booked
        self.rules = rules
        self.rates = rates
        self.calendar = calendar
        self.monthCount = max(monthCount, 1)
        self.currencyCode = currencyCode
        self.today = CalendarDay(today, in: calendar)
    }

    public var body: some View {
        let months = (0..<monthCount).map { offset in
            Timetable.month(containing: calendar.date(byAdding: .month, value: offset, to: today.date(in: calendar))!, calendar: calendar)
        }
        let last = CalendarDay(months.last!.month.end.addingTimeInterval(-1), in: calendar)
        let checkIns = Set(Timetable.checkInDays(from: today, through: last, booked: booked, rules: rules, rates: rates))
        let checkOuts = selection.flatMap { $0.nightCount == 0 ? $0.checkIn : nil }
            .map { Set(Timetable.checkOutDays(after: $0, booked: booked, rules: rules, rates: rates)) }
        let taken = Timetable.bookedNights(booked)

        VStack(spacing: 0) {
            Summary
            HStack(spacing: 0) {
                ForEach(Timetable.weekdaySymbols(calendar: calendar, style: .short), id: \.self) { symbol in
                    Text(symbol).font(.caption2.weight(.medium)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 6)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(months) { month in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(calendar.monthTitle(month.month.start)).font(.headline).padding(.horizontal, 12)
                            Grid(horizontalSpacing: 0, verticalSpacing: 4) {
                                ForEach(Array(month.weeks.enumerated()), id: \.offset) { _, week in
                                    GridRow {
                                        ForEach(week) { day in
                                            if day.isInMonth {
                                                DayCell(CalendarDay(day.date, in: calendar), checkIns: checkIns, checkOuts: checkOuts, taken: taken)
                                            } else {
                                                Color.clear.frame(height: 48)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            Divider()
            Footer
        }
    }

    // MARK: - Pieces

    private var Summary: some View {
        HStack(spacing: 0) {
            Field(label: String(localized: "Check-in", bundle: .module), value: selection.map { long($0.checkIn) }, active: selection == nil)
            Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)
            Field(label: String(localized: "Check-out", bundle: .module),
                  value: selection.flatMap { $0.nightCount > 0 ? long($0.checkOut) : nil },
                  active: selection?.nightCount == 0)
        }
        .padding()
    }

    private func Field(label: String, value: String?, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(value ?? String(localized: "Add date", bundle: .module))
                .font(.subheadline.weight(value == nil ? .regular : .semibold))
                .foregroundStyle(value == nil ? .secondary : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).strokeBorder(active ? Color.accentColor : Color.secondary.opacity(0.3),
                                                                   lineWidth: active ? 2 : 1))
    }

    @ViewBuilder private var Footer: some View {
        HStack {
            if let stay = selection, stay.nightCount > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    if let rates {
                        let quote = Timetable.quote(stay, rates: rates)
                        Text(money(quote.total)).font(.headline)
                        Text(breakdown(quote)).font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text(nights(stay.nightCount)).font(.headline)
                    }
                }
            } else {
                Text(selection == nil ? String(localized: "Choose your check-in date", bundle: .module) : String(localized: "Choose your check-out date", bundle: .module))
                    .font(.subheadline).foregroundStyle(.secondary)
                if rules.minimumNights > 1 {
                    Text("·", bundle: .module).foregroundStyle(.secondary)
                    Text(String(localized: "Minimum \(rules.minimumNights) nights", bundle: .module)).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if selection != nil {
                Button(String(localized: "Clear dates", bundle: .module)) { selection = nil }.buttonStyle(.borderless)
            }
        }
        .padding()
    }

    private func DayCell(_ day: CalendarDay, checkIns: Set<CalendarDay>, checkOuts: Set<CalendarDay>?, taken: Set<CalendarDay>) -> some View {
        let past = day < today
        let isStart = selection?.checkIn == day
        let isEnd = selection.map { $0.nightCount > 0 && $0.checkOut == day } ?? false
        let inside = selection.map { $0.nightCount > 0 && day > $0.checkIn && day < $0.checkOut } ?? false
        let enabled: Bool = {
            if past { return false }
            if let checkOuts { return checkOuts.contains(day) || checkIns.contains(day) }
            return checkIns.contains(day)
        }()
        let price = rates.flatMap { rates -> String? in
            guard !past, !taken.contains(day) else { return nil }
            return compactMoney(Timetable.quote(Stay(checkIn: day, nights: 1), rates: rates).nights.first?.amount ?? 0)
        }
        let ends = isStart || isEnd

        return Button {
            pick(day, checkOuts: checkOuts)
        } label: {
            VStack(spacing: 1) {
                Text(calendar.dayNumber(day.date(in: calendar)))
                    .font(.subheadline.weight(ends ? .bold : .regular))
                    .strikethrough(taken.contains(day) && !past)
                if let price {
                    Text(price).font(.system(size: 9)).foregroundStyle(ends ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.secondary))
                }
            }
            .foregroundStyle(ends ? AnyShapeStyle(.white) : enabled ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
            .frame(maxWidth: .infinity, minHeight: 48)
            .background {
                ZStack {
                    if inside || (ends && selection?.nightCount ?? 0 > 0) {
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.15))
                            .padding(.leading, isStart ? 24 : 0)
                            .padding(.trailing, isEnd ? 24 : 0)
                    }
                    if ends { Circle().fill(Color.accentColor).frame(width: 44, height: 44) }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled && !ends)
        .accessibilityLabel(Text(long(day)))
        .accessibilityValue(Text(isStart ? String(localized: "Check-in", bundle: .module) : isEnd ? String(localized: "Check-out", bundle: .module)
                                 : enabled ? (price ?? "") : String(localized: "Unavailable", bundle: .module)))
    }

    // MARK: - Choosing

    private func pick(_ day: CalendarDay, checkOuts: Set<CalendarDay>?) {
        withAnimation(.snappy(duration: 0.2)) {
            if let current = selection, current.nightCount == 0, checkOuts?.contains(day) == true {
                selection = Stay(checkIn: current.checkIn, checkOut: day)
            } else {
                selection = Stay(checkIn: day, checkOut: day)
            }
        }
    }

    // MARK: - Words

    private func long(_ day: CalendarDay) -> String {
        calendar.format(day.date(in: calendar)) { $0.weekday(.abbreviated).day().month(.abbreviated) }
    }

    private func money(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: currencyCode).precision(.fractionLength(0...2)))
    }

    private func compactMoney(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: currencyCode).precision(.fractionLength(0)))
    }

    private func nights(_ count: Int) -> String {
        String(localized: "\(count) nights", bundle: .module)
    }

    private func breakdown(_ quote: StayQuote) -> String {
        var parts = [nights(quote.nights.count)]
        if let discount = quote.discount {
            let percent = (discount.percent / 100).formatted(.percent.precision(.fractionLength(0...1)))
            parts.append(String(localized: "\(percent) off", bundle: .module))
        }
        if quote.perStayFee > 0 { parts.append(String(localized: "\(money(quote.perStayFee)) fee", bundle: .module)) }
        return parts.joined(separator: " · ")
    }
}
