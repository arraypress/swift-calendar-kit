//
//  CalendarDemoApp.swift
//  CalendarDemo
//
//  Every view in CalendarUI against one set of sample bookings.
//  `swift run CalendarDemo` on a Mac; add the package to an iOS app for a phone.
//

import SwiftUI
import CalendarUI
#if os(macOS)
import AppKit
#endif

@main
struct CalendarDemoApp: App {

    init() {
        #if os(macOS)
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        #endif
    }

    var body: some Scene {
        WindowGroup("CalendarKit") {
            DemoView()
                .frame(minWidth: 420, minHeight: 640)
        }
    }
}

struct Booking: RecurringEvent {
    var id = UUID()
    var title: String
    var start: Date
    var end: Date
    var isAllDay = false
    var color: Color
    var amount = 0
    var property = ""
    var recurrence: RecurrenceRule?
}

/// What every view shows: the bookings with their repeats expanded.
typealias Item = Occurrence<Booking>

enum Screen: String, CaseIterable, Identifiable {
    case day = "Day", week = "Week", threeDay = "3 Day", list = "List", board = "Board", month = "Month", year = "Year"
    case stays = "Stays", viewings = "Viewings"
    var id: String { rawValue }
}

struct DemoView: View {

    @State private var date = Date.now
    @State private var screen = Self.initialScreen
    @State private var message: String?
    @State private var bookings = Samples.bookings(around: .now)
    @State private var selection: Item.ID?
    @State private var stayProperty = Samples.properties[0]
    @State private var stay: Stay?
    @State private var viewingDay = Date.now
    @State private var viewing: SlotChoice<String>?

    /// Every booking with its repeats expanded, for the views.
    private var items: [Item] {
        let now = Date.now
        return Timetable.expand(bookings, in: DateInterval(start: now.addingTimeInterval(-120 * 86_400), end: now.addingTimeInterval(240 * 86_400)))
    }

    static var initialScreen: Screen {
        ProcessInfo.processInfo.environment["DEMO_SCREEN"].flatMap(Screen.init(rawValue:)) ?? .week
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $screen) {
                ForEach(Screen.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding()

            switch screen {
            case .day:
                DayView(events: items, date: $date, hours: Samples.officeHours, title: \.event.title, tint: \.event.color)
            case .week:
                WeekView(events: items, date: $date, hours: Samples.officeHours, title: \.event.title, tint: \.event.color)
            case .threeDay:
                WeekView(events: items, date: $date, dayCount: 3, hours: Samples.officeHours, title: \.event.title, tint: \.event.color)
            case .list:
                AgendaView(events: items, date: $date, title: \.event.title, tint: \.event.color)
            case .board:
                BookingBoard(resources: Samples.properties, events: items.filter { $0.isAllDay && !$0.event.property.isEmpty },
                             resourceOf: \.event.property, date: $date, name: { $0 }, title: \.event.guest, tint: \.event.color,
                             onMove: { item, property, interval in
                                 update(item.event.id) {
                                     $0.property = property
                                     $0.color = Samples.colors[property] ?? $0.color
                                     $0.title = "\(property) · \($0.guest)"
                                     $0.start = interval.start
                                     $0.end = interval.end
                                 }
                             },
                             onCreate: { property, interval in
                                 let nights = Calendar.current.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1
                                 var booking = Booking(title: "\(property) · New guest", start: interval.start, end: interval.end, isAllDay: true,
                                                       color: Samples.colors[property] ?? .accentColor, amount: nights * (Samples.nightly[property] ?? 100),
                                                       property: property)
                                 booking.id = UUID()
                                 bookings.append(booking)
                                 message = "New booking at \(property), \(nights) night\(nights == 1 ? "" : "s")"
                             })
            case .month:
                MonthView(events: items, date: $date, style: .titles, tint: \.event.color, title: \.event.title)
            case .year:
                YearView(events: items, date: $date, tint: \.event.color) { _ in screen = .month }
            case .stays:
                VStack(spacing: 0) {
                    Picker("Property", selection: $stayProperty) {
                        ForEach(Samples.properties, id: \.self) { Text($0).tag($0) }
                    }
                    .padding(.horizontal)
                    .onChange(of: stayProperty) { stay = nil }
                    StayPicker(selection: $stay, booked: stays(at: stayProperty), rules: StayRules(minimumNights: 2, maximumNights: 28),
                               rates: Samples.rates(for: stayProperty), currencyCode: "GBP")
                    if let stay, stay.nightCount > 0 {
                        Button("Book \(stay.nightCount) nights at \(stayProperty)") { book(stay, at: stayProperty) }
                            .buttonStyle(.borderedProminent)
                            .padding(.bottom)
                    }
                }
            case .viewings:
                HStack(alignment: .top, spacing: 0) {
                    SlotPicker(date: $viewingDay, selection: $viewing, resources: Samples.staff, name: { $0 },
                               hours: Samples.shifts, busy: Samples.staffBusy(from: items), length: 30 * 60, every: 15 * 60,
                               buffer: 15 * 60)
                    VStack(spacing: 12) {
                        OpeningHoursCard(Samples.officeHours, title: "Lettings office")
                        if let viewing {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Viewing with \(viewing.resource)").font(.headline)
                                Text(viewing.interval.start.formatted(date: .complete, time: .shortened)).font(.subheadline)
                                Button("Confirm viewing") {
                                    bookings.append(Booking(title: "Viewing · \(viewing.resource)", start: viewing.interval.start,
                                                            end: viewing.interval.end, color: .teal, property: ""))
                                    message = "Viewing booked with \(viewing.resource)"
                                    self.viewing = nil
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor.opacity(0.1)))
                        }
                    }
                    .frame(width: 300)
                    .padding()
                }
            }
        }
        .calendarEditing(Item.self, selection: $selection, onReschedule: reschedule, onDelete: delete, onCreate: { interval in
            bookings.append(Booking(title: "New event", start: interval.start, end: interval.end, color: .accentColor))
        }, onCopy: { item, interval in
            // A copy is a one-off, even of an occurrence of a series.
            var copy = item.event
            copy.id = UUID()
            copy.recurrence = nil
            copy.start = interval.start
            copy.end = interval.end
            bookings.append(copy)
        })
        .calendarUndo($bookings)
        .calendarEventDetail { (item: Item) in
            EventDetailView(item, title: item.event.title, tint: item.event.color) {
                BookingExtras(booking: item.event)
            }
        }
        .overlay(alignment: .bottom) {
            if let message {
                Text(message)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding()
                    .onTapGesture { self.message = nil }
            }
        }
    }
}

// MARK: - Applying edits

extension DemoView {

    /// A property's stays, as nights for the picker.
    private func stays(at property: String) -> [Stay] {
        bookings.filter { $0.isAllDay && $0.property == property }
            .map { Stay(checkIn: CalendarDay($0.start), checkOut: CalendarDay($0.end)) }
    }

    private func book(_ stay: Stay, at property: String) {
        let quote = Timetable.quote(stay, rates: Samples.rates(for: property))
        bookings.append(Booking(title: "\(property) · New guest", start: stay.checkIn.date(in: .current), end: stay.checkOut.date(in: .current),
                                isAllDay: true, color: Samples.colors[property] ?? .accentColor,
                                amount: NSDecimalNumber(decimal: quote.total).intValue, property: property))
        message = "Booked \(stay.nightCount) nights at \(property)"
        self.stay = nil
    }

    /// Changes the stored booking an occurrence came from.
    private func update(_ id: UUID, _ change: (inout Booking) -> Void) {
        guard let index = bookings.firstIndex(where: { $0.id == id }) else { return }
        change(&bookings[index])
    }

    /// A move or resize, applied the way Calendar.app does for each scope.
    private func reschedule(_ item: Item, to interval: DateInterval, scope: EditScope) {
        let series = item.event
        guard let rule = series.recurrence, scope != .allEvents else {
            // A one-off, or the whole series: shift the stored event by the same amount.
            let shift = interval.start.timeIntervalSince(item.start)
            let stretch = interval.duration - (item.end.timeIntervalSince(item.start))
            update(series.id) {
                $0.start = $0.start.addingTimeInterval(shift)
                $0.end = $0.end.addingTimeInterval(shift + stretch)
            }
            return
        }
        switch scope {
        case .thisEvent:
            // Skip this occurrence in the series, and add it back as a one-off at its new time.
            update(series.id) { $0.recurrence = rule.skipping(item.start) }
            var moved = series
            moved.id = UUID()
            moved.recurrence = nil
            moved.start = interval.start
            moved.end = interval.end
            bookings.append(moved)
        case .thisAndFollowing:
            // End the old series here; start a new one at the new time.
            update(series.id) { $0.recurrence = rule.ending(before: item.start) }
            var following = series
            following.id = UUID()
            following.recurrence = rule.unending
            following.start = interval.start
            following.end = interval.end
            bookings.append(following)
        case .allEvents:
            break
        }
    }

    private func delete(_ item: Item, scope: EditScope) {
        let series = item.event
        switch (series.recurrence, scope) {
        case (let rule?, .thisEvent): update(series.id) { $0.recurrence = rule.skipping(item.start) }
        case (let rule?, .thisAndFollowing): update(series.id) { $0.recurrence = rule.ending(before: item.start) }
        default: bookings.removeAll { $0.id == series.id }
        }
    }
}

/// The app's own part of the details card: what only a booking knows.
struct BookingExtras: View {
    let booking: Booking

    var body: some View {
        if !booking.property.isEmpty || booking.amount > 0 {
            Divider()
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                if !booking.property.isEmpty {
                    GridRow { Text("Property").foregroundStyle(.secondary); Text(booking.property) }
                }
                if booking.isAllDay && booking.amount > 0 {
                    GridRow { Text("Guest").foregroundStyle(.secondary); Text(booking.guest) }
                    GridRow {
                        Text("Total").foregroundStyle(.secondary)
                        Text(booking.amount, format: .currency(code: "GBP").precision(.fractionLength(0))).bold()
                    }
                }
            }
            .font(.subheadline)
            if booking.isAllDay && booking.amount > 0 {
                HStack {
                    Button("Message guest") {}
                    Button("Edit booking") {}
                }
                .padding(.top, 4)
            }
        }
    }
}

extension Booking {
    /// The guest's name, from "Property · Guest".
    var guest: String { title.components(separatedBy: " · ").last ?? title }
}

enum Samples {

    static let properties = ["406 Runway Rd", "Flat 3", "Harbour View", "Garden Cottage",
                             "Mill House", "The Old Bakery", "Seaview Loft", "Brook Barn"]

    static let colors: [String: Color] = [
        "406 Runway Rd": .blue, "Flat 3": .green, "Harbour View": .orange, "Garden Cottage": .purple,
        "Mill House": .teal, "The Old Bakery": .pink, "Seaview Loft": .indigo, "Brook Barn": .brown,
    ]

    static let guests = [
        "Ben Fry", "Ada Lovelace", "Grace Hopper", "Alan Kay", "Linus Torvalds", "Joan Clarke", "Tim Berners-Lee",
        "Hedy Lamarr", "Katherine Johnson", "Margaret Hamilton", "Dennis Ritchie", "Barbara Liskov", "Ken Thompson",
        "Radia Perlman", "Donald Knuth", "Frances Allen", "John McCarthy", "Karen Spärck Jones", "Edsger Dijkstra",
        "Shafi Goldwasser", "Guido van Rossum", "Anita Borg", "Bjarne Stroustrup", "Sophie Wilson", "Steve Furber",
        "Mary Kenneth Keller", "Niklaus Wirth", "Adele Goldberg", "Brian Kernighan", "Lynn Conway", "Vint Cerf",
        "Jean Sammet", "Chris Lattner", "Ruth Teitelbaum", "Fran Bilas", "Kay McNulty", "Betty Holberton",
    ]

    static let jobs = ["Plumber", "Electrician", "Gas safety check", "Boiler service", "Viewing", "Photographer",
                       "Window cleaner", "Inventory check", "Key handover", "Gardener", "Smoke alarm test"]

    /// The lettings office: weekdays with a late Thursday, Saturday mornings.
    static let officeHours: OpeningHours = {
        var hours = OpeningHours([try! TimeWindow("09:00", "17:30")], on: [.monday, .tuesday, .wednesday, .friday])
        hours.weekly[.thursday] = [try! TimeWindow("09:00", "19:00")]
        hours.weekly[.saturday] = [try! TimeWindow("10:00", "14:00")]
        return hours
    }()

    static let staff = ["Sam", "Priya", "Jordan"]

    /// Each agent's shifts.
    static func shifts(_ person: String) -> OpeningHours {
        switch person {
        case "Sam": OpeningHours([try! TimeWindow("09:00", "12:30"), try! TimeWindow("13:30", "17:30")], on: OpeningHours.weekdays)
        case "Priya": OpeningHours([try! TimeWindow("12:00", "19:00")], on: [.tuesday, .wednesday, .thursday, .friday, .saturday])
        default: OpeningHours([try! TimeWindow("08:00", "14:00")], on: [.monday, .wednesday, .friday, .saturday, .sunday])
        }
    }

    /// Each agent's existing appointments: the timed jobs, shared round by start time.
    static func staffBusy(from items: [Item]) -> [String: [DateInterval]] {
        var busy: [String: [DateInterval]] = [:]
        for item in items where !item.isAllDay {
            let person = staff[abs(Int(item.start.timeIntervalSinceReferenceDate / 900)) % staff.count]
            busy[person, default: []].append(DateInterval(start: item.start, end: max(item.end, item.start)))
        }
        return busy
    }

    /// A property's prices: its nightly rate, a dearer summer and Christmas,
    /// 10% off a week, 20% off four weeks, and a cleaning fee.
    static func rates(for property: String) -> NightlyRates {
        let base = Decimal(nightly[property] ?? 120)
        let year = Calendar.current.component(.year, from: .now)
        let day = { (y: Int, m: Int, d: Int) in try! CalendarDay(year: y, month: m, day: d) }
        return NightlyRates(
            nightly: base, weekendNightly: base * Decimal(1.25),
            seasons: [
                Season(name: "Summer", from: day(year, 6, 15), through: day(year, 9, 10), nightly: base * Decimal(1.4), minimumNights: 4),
                Season(name: "Christmas", from: day(year, 12, 20), through: day(year + 1, 1, 3), nightly: base * 2, minimumNights: 5),
            ],
            discounts: [StayDiscount(minimumNights: 7, percent: 10), StayDiscount(minimumNights: 28, percent: 20)],
            perStayFee: 60
        )
    }

    static let nightly: [String: Int] = [
        "406 Runway Rd": 145, "Flat 3": 95, "Harbour View": 240, "Garden Cottage": 120,
        "Mill House": 180, "The Old Bakery": 135, "Seaview Loft": 210, "Brook Barn": 160,
    ]

    /// About three months of a small holiday-let business around today:
    /// back-to-back stays on eight properties, a clean on every checkout,
    /// check-ins, maintenance visits, a weekly review — and one double
    /// booking, so the board has something to warn about. Seeded, so the
    /// same every run.
    static func bookings(around now: Date, calendar: Calendar = .current) -> [Booking] {
        var random = SeededRandom(seed: 2026)
        let today = calendar.startOfDay(for: now)
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today)! }
        func at(_ offset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day(offset))!
        }
        var bookings: [Booking] = []

        for property in properties {
            let color = colors[property]!
            var cursor = -21 + Int(random.next() % 5)
            while cursor < 62 {
                cursor += [0, 0, 1, 1, 2, 3, 5][Int(random.next() % 7)]
                let nights = [2, 3, 3, 4, 4, 5, 7, 7, 10][Int(random.next() % 9)]
                let guest = guests[Int(random.next() % UInt64(guests.count))]
                bookings.append(Booking(title: "\(property) · \(guest)", start: day(cursor), end: day(cursor + nights),
                                        isAllDay: true, color: color, amount: nights * nightly[property]!, property: property))
                if random.next() % 3 != 0 {
                    bookings.append(Booking(title: "Check-in · \(guest.components(separatedBy: " ")[0])",
                                            start: at(cursor, 16), end: at(cursor, 16, 30), color: color, property: property))
                }
                cursor += nights
                bookings.append(Booking(title: "Clean · \(property)", start: at(cursor, 11), end: at(cursor, 13),
                                        color: color, property: property))
            }
        }

        for offset in -21...62 {
            let weekday = calendar.component(.weekday, from: day(offset))
            guard weekday != 1 else { continue }
            for _ in 0..<Int(random.next() % 3) {
                let property = properties[Int(random.next() % UInt64(properties.count))]
                let job = jobs[Int(random.next() % UInt64(jobs.count))]
                let hour = 8 + Int(random.next() % 9), minute = [0, 15, 30, 45][Int(random.next() % 4)]
                let length = [30, 45, 60, 90, 120][Int(random.next() % 5)]
                let start = at(offset, hour, minute)
                bookings.append(Booking(title: "\(job) · \(property)", start: start,
                                        end: start.addingTimeInterval(TimeInterval(length * 60)),
                                        color: colors[property]!, property: property))
            }
        }

        let firstMonday = (0..<7).first { calendar.component(.weekday, from: day(-21 + $0)) == 2 }! - 21
        let firstThursday = (0..<7).first { calendar.component(.weekday, from: day(-21 + $0)) == 5 }! - 21
        let monthStart = calendar.dateInterval(of: .month, for: today)!.start
        let monthOffset = calendar.dateComponents([.day], from: today, to: monthStart).day!
        bookings += [
            Booking(title: "Weekly review", start: at(firstMonday, 9), end: at(firstMonday, 10), color: .gray,
                    recurrence: rule("FREQ=WEEKLY")),
            Booking(title: "Bin collection", start: at(firstThursday, 7), end: at(firstThursday, 7, 15), color: .mint,
                    recurrence: rule("FREQ=WEEKLY;INTERVAL=2")),
            Booking(title: "Fire alarm test", start: at(monthOffset, 10), end: at(monthOffset, 10, 30), color: .red,
                    recurrence: rule("the second tuesday of every month")),
            Booking(title: "Rent reconciliation", start: at(monthOffset, 16), end: at(monthOffset, 17), color: .gray,
                    recurrence: rule("the last friday of every month")),
            Booking(title: "Mortgage payments", start: monthStart, end: day(monthOffset + 1), isAllDay: true, color: .gray,
                    recurrence: rule("FREQ=MONTHLY;BYMONTHDAY=1")),
            Booking(title: "Insurance renewal", start: day(17), end: day(18), isAllDay: true, color: .yellow,
                    recurrence: rule("FREQ=YEARLY")),
            Booking(title: "Accountant call", start: at(firstMonday + 1, 14), end: at(firstMonday + 1, 14, 45), color: .gray,
                    recurrence: rule("FREQ=WEEKLY;INTERVAL=4;COUNT=3")),
        ]

        bookings.append(Booking(title: "Flat 3 · Double-booked guest", start: day(5), end: day(8), isAllDay: true,
                                color: .red, amount: 285, property: "Flat 3"))
        bookings.append(Booking(title: "Late arrival · Seaview Loft", start: at(2, 22), end: at(3, 1), color: .indigo,
                                property: "Seaview Loft"))
        return bookings
    }
}

/// A rule from RRULE text or plain words, both read by ChronoKit.
func rule(_ text: String) -> RecurrenceRule { try! RecurrenceRule(parsing: text) }

/// SplitMix64: a few lines, and the same numbers on every machine.
struct SeededRandom {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
