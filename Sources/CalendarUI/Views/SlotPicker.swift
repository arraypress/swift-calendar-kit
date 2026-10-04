//
//  SlotPicker.swift
//  CalendarUI
//

import SwiftUI

/// A chosen appointment: when, and with whom.
public struct SlotChoice<Resource: Hashable & Sendable>: Hashable, Sendable {

    /// When the appointment runs.
    public let interval: DateInterval

    /// Who or what it is booked with.
    public let resource: Resource

    public init(interval: DateInterval, resource: Resource) {
        self.interval = interval
        self.resource = resource
    }
}

/// The single resource of a ``SlotPicker`` that books one diary.
public enum SoleResource: Hashable, Sendable {
    case only
}

/// "Pick a time": a strip of days, then the free slots of the chosen day,
/// grouped into morning, afternoon and evening — the customer-facing side of
/// a booking app.
///
/// With several resources — staff, rooms, courts — the customer can pick one
/// or take anyone; "anyone" books the first resource free for that slot, in
/// the order given. Slots already started are not offered.
public struct SlotPicker<Resource: Hashable & Sendable>: View {

    @Environment(\.calendarStyle) private var style
    @Binding private var date: Date
    @Binding private var selection: SlotChoice<Resource>?
    @State private var only: Resource?
    private let resources: [Resource]
    private let name: (Resource) -> String
    private let hours: (Resource) -> OpeningHours
    private let busy: [Resource: [DateInterval]]
    private let length: TimeInterval
    private let step: TimeInterval
    private let buffer: TimeInterval
    private let dayCount: Int
    private let calendar: Calendar
    private let now: Date

    /// A picker across several resources.
    ///
    /// - Parameters:
    ///   - hours: each resource's opening hours — a person's shifts, a room's availability.
    ///   - busy: what each resource already has booked.
    ///   - length: how long an appointment lasts.
    ///   - step: how often one may start; the length unless given.
    ///   - buffer: kept clear between appointments.
    public init(date: Binding<Date>, selection: Binding<SlotChoice<Resource>?>, resources: [Resource],
                name: @escaping (Resource) -> String, hours: @escaping (Resource) -> OpeningHours,
                busy: [Resource: [DateInterval]] = [:], length: TimeInterval, every step: TimeInterval? = nil,
                buffer: TimeInterval = 0, dayCount: Int = 14, calendar: Calendar = .current, now: Date = .now) {
        _date = date
        _selection = selection
        self.resources = resources
        self.name = name
        self.hours = hours
        self.busy = busy
        self.length = length
        self.step = step ?? length
        self.buffer = buffer
        self.dayCount = max(dayCount, 1)
        self.calendar = calendar
        self.now = now
    }

    public var body: some View {
        let days = Timetable.days(from: now, count: dayCount, calendar: calendar)
        let chosen = slots(on: date)
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        DayChip(day, available: !slots(on: day).isEmpty)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            if resources.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Chip(String(localized: "Anyone"), on: only == nil) { only = nil; selection = nil }
                        ForEach(resources, id: \.self) { resource in
                            Chip(name(resource), on: only == resource) { only = resource; selection = nil }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }
            }
            Divider()
            if chosen.isEmpty {
                ContentUnavailableView(String(localized: "No times left"), systemImage: "calendar.badge.exclamationmark",
                                       description: Text(String(localized: "Try another day.")))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(Period.allCases, id: \.self) { period in
                            let group = chosen.filter { period.contains(calendar.component(.hour, from: $0.interval.start)) }
                            if !group.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(period.title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], spacing: 8) {
                                        ForEach(group, id: \.interval) { slot in SlotButton(slot) }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Slots

    /// The day's offerable slots, each with the resource it would book.
    private func slots(on date: Date) -> [SlotChoice<Resource>] {
        let day = CalendarDay(date, in: calendar)
        let pool = only.map { [$0] } ?? resources
        let windows = Dictionary(uniqueKeysWithValues: pool.map { ($0, Timetable.openIntervals(hours($0), from: day, through: day, calendar: calendar)) })
        return Timetable.slots(length: length, every: step, resources: pool, windows: windows, busy: busy, buffer: buffer)
            .filter { $0.interval.start > now }
            .compactMap { slot in slot.free.first.map { SlotChoice(interval: slot.interval, resource: $0) } }
    }

    private enum Period: CaseIterable {
        case morning, afternoon, evening

        func contains(_ hour: Int) -> Bool {
            switch self {
            case .morning: hour < 12
            case .afternoon: (12..<17).contains(hour)
            case .evening: hour >= 17
            }
        }

        var title: String {
            switch self {
            case .morning: String(localized: "Morning")
            case .afternoon: String(localized: "Afternoon")
            case .evening: String(localized: "Evening")
            }
        }
    }

    // MARK: - Pieces

    private func DayChip(_ day: Date, available: Bool) -> some View {
        let selected = calendar.isDate(day, inSameDayAs: date)
        return Button {
            date = day
            selection = nil
        } label: {
            VStack(spacing: 2) {
                Text(calendar.format(day) { $0.weekday(.abbreviated) }).font(.caption2)
                Text(calendar.dayNumber(day)).font(.headline.monospacedDigit())
                Circle().fill(available ? Color.green : Color.clear).frame(width: 4, height: 4)
            }
            .frame(width: 48, height: 58)
            .foregroundStyle(selected ? AnyShapeStyle(.white) : available ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
            .background(RoundedRectangle(cornerRadius: 12).fill(selected ? Color.accentColor : Color.secondary.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(calendar.format(day) { $0.weekday(.wide).day().month(.wide) }))
        .accessibilityValue(Text(available ? "" : String(localized: "No times left")))
    }

    private func Chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .foregroundStyle(on ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .background(Capsule().fill(on ? Color.accentColor : Color.secondary.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }

    private func SlotButton(_ slot: SlotChoice<Resource>) -> some View {
        let selected = selection?.interval == slot.interval
        return Button {
            selection = selected ? nil : slot
        } label: {
            VStack(spacing: 1) {
                Text(calendar.format(slot.interval.start) { $0.hour().minute() }).font(.subheadline.weight(.semibold).monospacedDigit())
                if resources.count > 1 && only == nil && selected {
                    Text(name(slot.resource)).font(.caption2).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(Color.accentColor))
            .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Color.accentColor : Color.accentColor.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(calendar.timeRange(slot.interval.start, slot.interval.end)))
    }
}

extension SlotPicker where Resource == SoleResource {

    /// A picker for one diary: its opening hours and what is already booked.
    public init(date: Binding<Date>, selection: Binding<DateInterval?>, hours: OpeningHours, busy: [DateInterval] = [],
                length: TimeInterval, every step: TimeInterval? = nil, buffer: TimeInterval = 0, dayCount: Int = 14,
                calendar: Calendar = .current, now: Date = .now) {
        self.init(date: date,
                  selection: Binding(get: { selection.wrappedValue.map { SlotChoice(interval: $0, resource: .only) } },
                                     set: { selection.wrappedValue = $0?.interval }),
                  resources: [.only], name: { _ in "" }, hours: { _ in hours }, busy: [.only: busy],
                  length: length, every: step, buffer: buffer, dayCount: dayCount, calendar: calendar, now: now)
    }
}
