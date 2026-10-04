//
//  EventDetail.swift
//  CalendarUI
//
//  Tapping an event shows its details beside it: a popover on iPad and Mac,
//  a sheet on iPhone, Apple TV and Watch. Set what the details are once, high up, with
//  `.calendarEventDetail { ... }`; every calendar view below uses it.
//

import SwiftUI

/// Builds the details for an event of whatever type a view holds.
struct EventDetailBuilder: Sendable {
    let build: @MainActor @Sendable (Any) -> AnyView?
}

private struct EventDetailKey: EnvironmentKey {
    static let defaultValue: EventDetailBuilder? = nil
}

extension EnvironmentValues {
    var eventDetail: EventDetailBuilder? {
        get { self[EventDetailKey.self] }
        set { self[EventDetailKey.self] = newValue }
    }
}

extension View {

    /// What to show when an event is tapped in any calendar view inside —
    /// usually an ``EventDetailView``. Views of other event types are
    /// unaffected; set one of these per type.
    public func calendarEventDetail<Event: CalendarEvent, Content: View>(
        for type: Event.Type = Event.self, @ViewBuilder _ content: @escaping (Event) -> Content
    ) -> some View {
        environment(\.eventDetail, EventDetailBuilder { value in
            (value as? Event).map { AnyView(content($0)) }
        })
    }

    /// Calls `onSelect` on a tap. With editing on, the first tap selects and
    /// a second opens the details; without it, a tap opens them straight away.
    /// Adds the selection ring, a hover highlight and a context menu.
    func selectable<Event: CalendarEvent>(_ event: Event, calendar: Calendar, onSelect: ((Event) -> Void)?) -> some View {
        modifier(Selectable(event: event, calendar: calendar, onSelect: onSelect))
    }
}

private struct Selectable<Event: CalendarEvent>: ViewModifier {

    @Environment(\.eventDetail) private var detail
    @Environment(\.calendarEditor) private var editor
    @Environment(\.calendarStyle) private var style
    @State private var isShowing = false
    @State private var isHovered = false
    let event: Event
    let calendar: Calendar
    let onSelect: ((Event) -> Void)?

    func body(content: Content) -> some View {
        let selected = editor?.isSelected(event.id) ?? false
        let original = DateInterval(start: event.start, end: max(event.end, event.start))
        let canMove = editor?.canReschedule == true
        let shape = RoundedRectangle(cornerRadius: style.tileCornerRadius, style: .continuous)
        content
            .brightness(isHovered && !selected ? 0.03 : 0)
            .overlay {
                if selected {
                    shape.strokeBorder(Color.accentColor, lineWidth: 2)
                        .shadow(color: .accentColor.opacity(0.35), radius: 4)
                        .allowsHitTesting(false)
                }
            }
            .onTapGesture {
                onSelect?(event)
                if let editor, !editor.isSelected(event.id) {
                    editor.select(event, id: AnyHashable(event.id))
                } else if detail?.build(event) != nil {
                    isShowing = true
                }
            }
            #if os(macOS) || os(iOS) || os(visionOS)
            .onHover { isHovered = $0 }
            .contextMenu {
                if detail?.build(event) != nil {
                    Button("Show Details", systemImage: "info.circle") { isShowing = true }
                }
                if let editor, editor.canCopy {
                    Button("Copy", systemImage: "doc.on.doc") { editor.copy(event) }
                    if editor.canDelete { Button("Cut", systemImage: "scissors") { editor.cut(event) } }
                    Button("Duplicate", systemImage: "plus.square.on.square") { editor.duplicate(event) }
                }
                if let editor, editor.canDelete {
                    Divider()
                    Button("Delete", systemImage: "trash", role: .destructive) { editor.delete(event) }
                }
            }
            #endif
            // One element for VoiceOver: the tile's own text, then when it is.
            .accessibilityElement(children: .combine)
            .accessibilityValue(Text(Spoken.when(event, calendar: calendar)))
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction(named: Text("Show Details")) { if detail?.build(event) != nil { isShowing = true } }
            .accessibilityAction(named: Text("Move 15 Minutes Earlier")) {
                if canMove, !event.isAllDay { editor?.reschedule(event, Timetable.moved(original, by: -(editor?.snap ?? 900), snap: editor?.snap ?? 900, calendar: calendar)) }
            }
            .accessibilityAction(named: Text("Move 15 Minutes Later")) {
                if canMove, !event.isAllDay { editor?.reschedule(event, Timetable.moved(original, by: editor?.snap ?? 900, snap: editor?.snap ?? 900, calendar: calendar)) }
            }
            .accessibilityAction(named: Text("Move to Previous Day")) {
                if canMove { editor?.reschedule(event, Timetable.moved(original, byDays: -1, calendar: calendar)) }
            }
            .accessibilityAction(named: Text("Move to Next Day")) {
                if canMove { editor?.reschedule(event, Timetable.moved(original, byDays: 1, calendar: calendar)) }
            }
            .accessibilityAction(named: Text("Delete")) { if editor?.canDelete == true { editor?.delete(event) } }
            #if os(tvOS) || os(watchOS)
            .sheet(isPresented: $isShowing) { detailView }
            #else
            .popover(isPresented: $isShowing) { detailView }
            #endif
    }

    @ViewBuilder private var detailView: some View {
        if let view = detail?.build(event) {
            view
                .frame(minWidth: 300, idealWidth: 340)
                .presentationDetents([.medium, .large])
        }
    }
}

/// How an event is read aloud: "Monday 5 October, 09:30 to 11:30, repeats".
enum Spoken {

    static func when<Event: CalendarEvent>(_ event: Event, calendar: Calendar) -> String {
        let day = { (date: Date) in calendar.format(date) { $0.weekday(.wide).day().month(.wide) } }
        let time = { (date: Date) in calendar.format(date) { $0.hour().minute() } }
        var parts: [String]
        if event.isAllDay {
            let last = event.end > event.start ? event.end.addingTimeInterval(-1) : event.start
            parts = calendar.isDate(event.start, inSameDayAs: last)
                ? [day(event.start), String(localized: "all day")]
                : [String(localized: "\(day(event.start)) to \(day(last))"), String(localized: "all day")]
        } else if calendar.isDate(event.start, inSameDayAs: event.end) || event.end <= event.start {
            parts = [day(event.start), String(localized: "\(time(event.start)) to \(time(event.end))")]
        } else {
            parts = [String(localized: "\(day(event.start)) \(time(event.start)) to \(day(event.end)) \(time(event.end))")]
        }
        if event.isRecurring { parts.append(String(localized: "repeats")) }
        return parts.joined(separator: ", ")
    }
}
