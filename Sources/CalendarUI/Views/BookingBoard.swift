//
//  BookingBoard.swift
//  CalendarUI
//

import SwiftUI

/// A bookings board: one row per resource — a property, a room, a member of
/// staff — days across the top, and each booking a bar along its row. The
/// view a host or a front desk lives in, because free time is the gaps.
///
/// With `nights` on (the default) a stay is drawn from the middle of its
/// check-in day to the middle of its check-out day, so a turnover day shows
/// one guest leaving and the next arriving. Double-booked days are shaded.
public struct BookingBoard<Resource: Hashable, Event: CalendarEvent, Label: View, Bar: View>: View {

    @Environment(\.calendarStyle) private var style
    @Environment(\.calendarEditor) private var editor
    @Environment(\.calendarUndo) private var undo
    @ScaledMetric(relativeTo: .caption) private var textScale: CGFloat = 1
    @Binding private var date: Date
    @State private var width: CGFloat = 0
    @State private var drag: BarDrag?
    @State private var sweep: (row: Int, from: Int, to: Int)?
    @State private var hoveredRow: Int?
    private let resources: [Resource]
    private let events: [Event]
    private let resourceOf: (Event) -> Resource
    private let calendar: Calendar
    private let dayCount: Int
    private let nights: Bool
    private let label: (BoardRow<Resource, Event>) -> Label
    private let bar: (Event, LaneBar<Event>) -> Bar
    private let onSelect: ((Event) -> Void)?
    private let onSelectFree: ((Resource, Date) -> Void)?
    private let onMove: ((Event, Resource, DateInterval) -> Void)?
    private let onCreate: ((Resource, DateInterval) -> Void)?

    /// A bar being dragged: moved (days across, rows down) or stretched (its checkout).
    private struct BarDrag {
        var id: AnyHashable
        var row: Int
        var translation: CGSize
        var stretching: Bool
    }

    /// A board of `dayCount` days from `date`.
    ///
    /// - Parameters:
    ///   - resourceOf: which resource a booking belongs to.
    ///   - nights: draw bookings as nights, check-in noon to check-out noon.
    ///   - onSelectFree: a tap on a free day in a resource's row — the start
    ///     of a new booking.
    ///   - onMove: a booking dragged to other days or another resource, or its
    ///     checkout dragged by its right edge. Leave it out and bars stay put.
    ///   - onCreate: free days swept out in a row — a new booking for that
    ///     resource, check-in to check-out.
    public init(
        resources: [Resource], events: [Event], resourceOf: @escaping (Event) -> Resource,
        date: Binding<Date>, calendar: Calendar = .current, dayCount: Int = 21, nights: Bool = true,
        onSelect: ((Event) -> Void)? = nil, onSelectFree: ((Resource, Date) -> Void)? = nil,
        onMove: ((Event, Resource, DateInterval) -> Void)? = nil, onCreate: ((Resource, DateInterval) -> Void)? = nil,
        @ViewBuilder label: @escaping (Resource) -> Label, @ViewBuilder bar: @escaping (Event) -> Bar
    ) {
        _date = date
        self.resources = resources
        self.events = events
        self.resourceOf = resourceOf
        self.calendar = calendar
        self.dayCount = max(dayCount, 1)
        self.nights = nights
        self.label = { label($0.resource) }
        self.bar = { event, _ in bar(event) }
        self.onSelect = onSelect
        self.onSelectFree = onSelectFree
        self.onMove = onMove
        self.onCreate = onCreate
    }

    init(
        resources: [Resource], events: [Event], resourceOf: @escaping (Event) -> Resource,
        date: Binding<Date>, calendar: Calendar, dayCount: Int, nights: Bool,
        onSelect: ((Event) -> Void)?, onSelectFree: ((Resource, Date) -> Void)?,
        onMove: ((Event, Resource, DateInterval) -> Void)?, onCreate: ((Resource, DateInterval) -> Void)?,
        rowLabel: @escaping (BoardRow<Resource, Event>) -> Label, placedBar: @escaping (Event, LaneBar<Event>) -> Bar
    ) {
        _date = date
        self.resources = resources
        self.events = events
        self.resourceOf = resourceOf
        self.calendar = calendar
        self.dayCount = max(dayCount, 1)
        self.nights = nights
        self.label = rowLabel
        self.bar = placedBar
        self.onSelect = onSelect
        self.onSelectFree = onSelectFree
        self.onMove = onMove
        self.onCreate = onCreate
    }

    public var body: some View {
        let days = Timetable.days(from: date, count: dayCount, calendar: calendar)
        let rows = Timetable.board(events, resources: resources, resourceOf: resourceOf, across: days, calendar: calendar)
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(calendar.rangeTitle(days))
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Today") { withAnimation(.snappy) { date = .now } }
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
            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: headerHeight)
                        Divider()
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            label(row)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: height(of: row))
                                .background(hoveredRow == index ? Color.primary.opacity(0.04) : .clear)
                            Divider()
                        }
                    }
                    .frame(width: style.boardLabelWidth)
                    Divider()
                    ScrollView(.horizontal) {
                        VStack(alignment: .leading, spacing: 0) {
                            DayHeader(days: days)
                            Divider()
                            let tops = rowTops(rows)
                            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                                RowView(row: row, index: index, rows: rows, tops: tops, days: days)
                                    .zIndex(drag?.row == index ? 1 : 0)
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onAppear { editor?.calendar = calendar }
    }

    private let headerHeight: CGFloat = 52

    /// One lane's height, grown with the reader's text size.
    private var barUnit: CGFloat { style.boardBarHeight * max(textScale, 1) }

    /// Days widen to fill the window, never narrower than the style's
    /// minimum — below that the board scrolls sideways instead.
    private var dayWidth: CGFloat {
        let available = width - style.boardLabelWidth - 1
        return max(style.boardDayWidth, available / CGFloat(dayCount))
    }

    private func height(of row: BoardRow<Resource, Event>) -> CGFloat {
        CGFloat(max(row.lanes.laneCount, 1)) * barUnit + 8
    }

    /// Where each row starts, counting the hairline dividers between them.
    private func rowTops(_ rows: [BoardRow<Resource, Event>]) -> [CGFloat] {
        var tops: [CGFloat] = []
        var y: CGFloat = 0
        for row in rows {
            tops.append(y)
            y += height(of: row) + 1
        }
        return tops
    }

    /// The row under a point measured from the first row's top.
    private func rowIndex(at y: CGFloat, tops: [CGFloat]) -> Int {
        max((tops.lastIndex { $0 <= y }) ?? 0, 0)
    }

    private func DayHeader(days: [Date]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element) { index, day in
                let firstOfMonth = calendar.component(.day, from: day) == 1
                VStack(spacing: 1) {
                    Text(index == 0 || firstOfMonth ? calendar.monthName(day) : " ")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(calendar.format(day) { $0.weekday(.narrow) })
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    DayNumber(day: day, calendar: calendar, isSelected: calendar.isToday(day), font: .footnote)
                        .scaleEffect(0.85)
                }
                .frame(width: dayWidth, height: headerHeight)
            }
        }
    }

    private func RowView(row: BoardRow<Resource, Event>, index: Int, rows: [BoardRow<Resource, Event>],
                         tops: [CGFloat], days: [Date]) -> some View {
        let barHeight = barUnit
        let clashes = Set(row.clashingDays)
        let column = { (x: CGFloat) in min(max(Int(x / max(dayWidth, 1)), 0), days.count - 1) }
        return ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                ForEach(days.indices, id: \.self) { day in
                    Rectangle()
                        .fill(fill(for: days[day], clash: clashes.contains(day)))
                        .frame(width: dayWidth)
                        .overlay(alignment: .leading) { Rectangle().fill(.separator).frame(width: 0.5) }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editor?.select(nil, id: nil)
                            if row.isFree[day] { onSelectFree?(row.resource, days[day]) }
                        }
                }
            }
            .background(hoveredRow == index ? Color.primary.opacity(0.03) : .clear)
            .editDrag(enabled: onCreate != nil) { step in
                sweep = (index, column(step.start.x), column(step.start.x + step.translation.width))
            } onEnded: { step in
                let a = column(step.start.x), b = column(step.start.x + step.translation.width)
                let first = days[min(a, b)], last = days[max(a, b)]
                sweep = nil
                let stay = DateInterval(start: first, end: calendar.date(byAdding: .day, value: 1, to: last) ?? last)
                recordingUndo(undo, String(localized: "New Booking")) { onCreate?(row.resource, stay) }
            }
            if let sweep, sweep.row == index {
                let lo = CGFloat(min(sweep.from, sweep.to)), hi = CGFloat(max(sweep.from, sweep.to) + 1)
                RoundedRectangle(cornerRadius: style.tileCornerRadius)
                    .fill(Color.accentColor.opacity(0.2))
                    .overlay(RoundedRectangle(cornerRadius: style.tileCornerRadius).strokeBorder(Color.accentColor, lineWidth: 1))
                    .frame(width: (hi - lo) * dayWidth - 3, height: barHeight - 6)
                    .padding(.leading, lo * dayWidth + 1.5)
                    .padding(.top, 7)
                    .allowsHitTesting(false)
            }
            ForEach(row.lanes.bars) { placed in
                let id = AnyHashable(placed.event.id)
                let active = drag?.id == id ? drag : nil
                let dayShift = active.map { Int(($0.translation.width / max(dayWidth, 1)).rounded()) } ?? 0
                let laneTop = 4 + CGFloat(placed.lane) * barHeight + 3
                let target = active.map { !$0.stretching ? rowIndex(at: tops[index] + laneTop + $0.translation.height, tops: tops) : index } ?? index
                let start = CGFloat(placed.firstDay) + (nights && !placed.continuesBefore ? 0.5 : 0)
                let end = min(CGFloat(placed.lastDay + 1) + (nights && !placed.continuesAfter ? 0.5 : 0), CGFloat(days.count))
                let stretchShift = active?.stretching == true ? CGFloat(max(dayShift, -(placed.lastDay - placed.firstDay))) : 0
                let moveShift = active?.stretching == false ? CGFloat(dayShift) : 0
                bar(placed.event, placed)
                    .frame(width: max((end - start + stretchShift) * dayWidth - 3, 0), height: barHeight - 6)
                    .selectable(placed.event, calendar: calendar, onSelect: onSelect)
                    .overlay(alignment: .trailing) {
                        if onMove != nil, editor?.isSelected(placed.event.id) == true, !placed.continuesAfter {
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: 5, height: barHeight - 16)
                                .padding(.horizontal, 3)
                                .contentShape(Rectangle().inset(by: -6))
                                .editDrag(in: .global) { step in
                                    drag = BarDrag(id: id, row: index, translation: step.translation, stretching: true)
                                } onEnded: { step in
                                    let days = Int((step.translation.width / max(dayWidth, 1)).rounded())
                                    drag = nil
                                    guard days != 0 else { return }
                                    let original = DateInterval(start: placed.event.start, end: max(placed.event.end, placed.event.start))
                                    let checkout = calendar.date(byAdding: .day, value: days, to: original.end) ?? original.end
                                    let earliest = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: original.start)) ?? original.end
                                    recordingUndo(undo, String(localized: "Change Checkout")) {
                                        onMove?(placed.event, row.resource, DateInterval(start: original.start, end: max(checkout, earliest)))
                                    }
                                }
                                .resizeCursor(vertical: false)
                        }
                    }
                    .offset(x: moveShift * dayWidth, y: tops[target] - tops[index])
                    .shadow(color: .black.opacity(active == nil ? 0 : 0.25), radius: active == nil ? 0 : 6, y: 3)
                    .editDrag(enabled: onMove != nil) { step in
                        drag = BarDrag(id: id, row: index, translation: step.translation, stretching: false)
                        if editor?.isSelected(placed.event.id) == false { editor?.select(placed.event, id: id) }
                    } onEnded: { step in
                        let days = Int((step.translation.width / max(dayWidth, 1)).rounded())
                        let landed = rowIndex(at: tops[index] + laneTop + step.translation.height, tops: tops)
                        drag = nil
                        guard days != 0 || landed != index else { return }
                        let original = DateInterval(start: placed.event.start, end: max(placed.event.end, placed.event.start))
                        recordingUndo(undo, String(localized: "Move Booking")) {
                            onMove?(placed.event, rows[landed].resource, Timetable.moved(original, byDays: days, calendar: calendar))
                        }
                    }
                    .padding(.leading, start * dayWidth + 1.5)
                    .padding(.top, laneTop)
            }
        }
        .frame(width: CGFloat(days.count) * dayWidth, height: height(of: row), alignment: .topLeading)
        #if os(macOS) || os(iOS) || os(visionOS)
        .onHover { inside in hoveredRow = inside ? index : (hoveredRow == index ? nil : hoveredRow) }
        #endif
    }

    private func fill(for day: Date, clash: Bool) -> AnyShapeStyle {
        if clash { return AnyShapeStyle(Color.red.opacity(0.15)) }
        if calendar.isToday(day) { return AnyShapeStyle(style.todayColor.opacity(0.07)) }
        if calendar.isDateInWeekend(day) { return AnyShapeStyle(Color.primary.opacity(0.04)) }
        return AnyShapeStyle(Color.clear)
    }

    private func move(by pages: Int) {
        withAnimation(.snappy) {
            date = calendar.date(byAdding: .day, value: pages * 7, to: date) ?? date
        }
    }
}

extension BookingBoard where Label == BoardRowLabel, Bar == EventTile<EventTileLabel> {

    /// A board with the standard look: each resource's name and how full it
    /// is, and bookings as titled tiles in a colour with their length.
    public init(
        resources: [Resource], events: [Event], resourceOf: @escaping (Event) -> Resource,
        date: Binding<Date>, calendar: Calendar = .current, dayCount: Int = 21, nights: Bool = true,
        name: @escaping (Resource) -> String, title: @escaping (Event) -> String,
        tint: @escaping (Event) -> Color = { _ in .accentColor },
        onSelect: ((Event) -> Void)? = nil, onSelectFree: ((Resource, Date) -> Void)? = nil,
        onMove: ((Event, Resource, DateInterval) -> Void)? = nil, onCreate: ((Resource, DateInterval) -> Void)? = nil
    ) {
        self.init(resources: resources, events: events, resourceOf: resourceOf, date: date, calendar: calendar,
                  dayCount: dayCount, nights: nights, onSelect: onSelect, onSelectFree: onSelectFree,
                  onMove: onMove, onCreate: onCreate,
                  rowLabel: { row in BoardRowLabel(name: name(row.resource), occupancy: row.occupancy, clashes: !row.clashingDays.isEmpty) },
                  placedBar: { event, placed in
                      let length = BoardText.length(of: event, nights: nights, calendar: calendar)
                      return EventTile(title(event), subtitle: placed.length > 2 ? length : nil, tint: tint(event), repeats: event.isRecurring)
                  })
    }
}

/// A board row's name, with how full it is and a warning for double bookings.
public struct BoardRowLabel: View {

    let name: String
    let occupancy: Double
    let clashes: Bool

    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            HStack(spacing: 6) {
                Capsule()
                    .fill(.quaternary)
                    .frame(width: 44, height: 4)
                    .overlay(alignment: .leading) {
                        Capsule().fill(.tint).frame(width: 44 * min(max(occupancy, 0), 1), height: 4)
                    }
                Text(occupancy, format: .percent.precision(.fractionLength(0)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                if clashes {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .help("Double booked")
                }
            }
        }
    }
}

enum BoardText {

    /// "3 nights", or "3 days" when bookings are not counted in nights.
    static func length<E: CalendarEvent>(of event: E, nights: Bool, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: event.start), to: calendar.startOfDay(for: event.end)).day ?? 0
        let count = max(days, 1)
        switch (nights, count) {
        case (true, 1): return String(localized: "1 night")
        case (true, _): return String(localized: "\(count) nights")
        case (false, 1): return String(localized: "1 day")
        case (false, _): return String(localized: "\(count) days")
        }
    }
}
