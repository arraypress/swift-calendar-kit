//
//  AgendaView.swift
//  CalendarUI
//

import SwiftUI

/// Events as a list, a heading per day — the view everyone already knows how
/// to read. Days with nothing on are skipped.
public struct AgendaView<Event: CalendarEvent, Row: View>: View {

    @Binding private var date: Date
    private let events: [Event]
    private let calendar: Calendar
    private let dayCount: Int
    private let row: (AgendaEntry<Event>) -> Row
    private let onSelect: ((Event) -> Void)?

    /// A list of `dayCount` days from `date`, each event drawn with your own row.
    public init(
        events: [Event], date: Binding<Date>, calendar: Calendar = .current, dayCount: Int = 30,
        onSelect: ((Event) -> Void)? = nil, @ViewBuilder row: @escaping (AgendaEntry<Event>) -> Row
    ) {
        _date = date
        self.events = events
        self.calendar = calendar
        self.dayCount = max(dayCount, 1)
        self.row = row
        self.onSelect = onSelect
    }

    public var body: some View {
        let days = Timetable.days(from: date, count: dayCount, calendar: calendar)
        let list = Timetable.agenda(events, on: days, calendar: calendar)
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(calendar.rangeTitle(days))
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(String(localized: "Today", bundle: .module)) { withAnimation(.snappy) { date = .now } }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tint)
                    .padding(.trailing, 6)
                StepButton(systemImage: "chevron.left") { move(by: -1) }
                StepButton(systemImage: "chevron.right") { move(by: 1) }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            Divider()
            if list.isEmpty {
                ContentUnavailableView("Nothing scheduled", systemImage: "calendar")
            } else {
                List {
                    ForEach(list) { day in
                        Section {
                            ForEach(day.entries) { entry in
                                row(entry)
                                    .contentShape(Rectangle())
                                    .selectable(entry.event, calendar: calendar, onSelect: onSelect)
                                    .listRowInsets(EdgeInsets())
                            }
                        } header: {
                            DayHeading(day: day.day.start, calendar: calendar)
                                .listRowInsets(EdgeInsets())
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func move(by pages: Int) {
        withAnimation(.snappy) {
            date = calendar.date(byAdding: .day, value: pages * dayCount, to: date) ?? date
        }
    }
}

extension AgendaView where Row == AgendaRow {

    /// A list with the standard row: times, a colour and a title.
    public init(
        events: [Event], date: Binding<Date>, calendar: Calendar = .current, dayCount: Int = 30,
        title: @escaping (Event) -> String, tint: @escaping (Event) -> Color = { _ in .accentColor },
        onSelect: ((Event) -> Void)? = nil
    ) {
        self.init(events: events, date: date, calendar: calendar, dayCount: dayCount, onSelect: onSelect) { entry in
            AgendaRow(entry, calendar: calendar, title: title(entry.event), tint: tint(entry.event))
        }
    }
}

/// The standard list row: start and end times, a colour bar and a title.
public struct AgendaRow: View {

    private let times: (String, String?)
    private let title: String
    private let tint: Color
    private let repeats: Bool

    /// A row for one day's part of an event.
    public init<Event: CalendarEvent>(_ entry: AgendaEntry<Event>, calendar: Calendar = .current, title: String, tint: Color) {
        let time = { (date: Date) in calendar.format(date) { $0.hour().minute() } }
        if entry.isAllDay {
            times = (String(localized: "All day", bundle: .module),
                     entry.eventDayCount > 1 ? String(localized: "Day \(entry.dayOfEvent) of \(entry.eventDayCount)", bundle: .module) : nil)
        } else {
            times = (entry.continuesFromPreviousDay ? "…" : time(entry.start),
                     entry.continuesToNextDay ? "…" : time(entry.end))
        }
        self.title = title
        self.tint = tint
        self.repeats = entry.event.isRecurring
    }

    public var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(times.0).font(.subheadline)
                if let end = times.1 {
                    Text(end).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(width: 84, alignment: .trailing)
            Capsule().fill(tint).frame(width: 4)
            Text(title).font(.body)
            if repeats { RepeatBadge().font(.caption) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

/// "Today · Sun 4 Oct", pinned while its day scrolls past.
private struct DayHeading: View {

    @Environment(\.calendarStyle) private var style
    let day: Date
    let calendar: Calendar

    var body: some View {
        let today = calendar.isToday(day)
        HStack(spacing: 6) {
            if today {
                Text("Today", bundle: .module).foregroundStyle(style.todayColor)
            } else if calendar.isDateInTomorrow(day) {
                Text("Tomorrow", bundle: .module)
            } else if calendar.isDateInYesterday(day) {
                Text("Yesterday", bundle: .module)
            }
            if today || calendar.isDateInTomorrow(day) || calendar.isDateInYesterday(day) {
                Text("·", bundle: .module).foregroundStyle(.secondary)
            }
            Text(calendar.format(day) { $0.weekday(.wide).day().month(.wide) })
                .foregroundStyle(today ? AnyShapeStyle(style.todayColor) : AnyShapeStyle(.primary))
        }
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
