//
//  EditingHost.swift
//  CalendarUI
//
//  Selecting, moving, resizing, creating and deleting, for every calendar
//  view inside `.calendarEditing(...)`. The views never change your data:
//  they say what the user did, already snapped and — for repeating events —
//  with the scope the user picked, and your closures apply it.
//

import SwiftUI

extension View {

    /// Turns on editing for every calendar view inside.
    ///
    /// - Click an event to select it (click again for its details), drag it to
    ///   move it, drag its bottom edge to resize it, press Delete to delete it.
    ///   On iPhone and iPad, press and hold to start a drag.
    /// - Drag across empty time to create an event.
    /// - Moving or deleting an occurrence of a repeating event first asks
    ///   "This Event, This and Following, or All Events?"; the answer arrives
    ///   as the ``EditScope``. One-off events always get `.thisEvent`.
    ///
    /// - Copy, cut and paste (Cmd-C, Cmd-X, Cmd-V) and duplicate (Cmd-D), or
    ///   from the context menu: a paste lands on the time or day last clicked.
    ///
    /// Leave a closure out and that edit is off: no `onReschedule`, no dragging.
    ///
    /// - Parameters:
    ///   - selection: the selected event's id, or nil.
    ///   - snapping: what drags snap to, in seconds; 15 minutes by default.
    ///   - onCopy: make a copy of an event at an interval — what paste and
    ///     duplicate both ask for.
    public func calendarEditing<Event: CalendarEvent>(
        _ type: Event.Type = Event.self,
        selection: Binding<Event.ID?>,
        snapping: TimeInterval = 15 * 60,
        onReschedule: ((Event, DateInterval, EditScope) -> Void)? = nil,
        onDelete: ((Event, EditScope) -> Void)? = nil,
        onCreate: ((DateInterval) -> Void)? = nil,
        onCopy: ((Event, DateInterval) -> Void)? = nil
    ) -> some View where Event.ID: Sendable {
        modifier(EditingHost(selection: selection, snap: snapping, onReschedule: onReschedule,
                             onDelete: onDelete, onCreate: onCreate, onCopy: onCopy))
    }
}

/// The typed side of editing: owns the editor, keeps it in step with the
/// caller's selection, handles the keyboard, and asks about series edits.
struct EditingHost<Event: CalendarEvent>: ViewModifier where Event.ID: Sendable {

    @Binding var selection: Event.ID?
    let snap: TimeInterval
    let onReschedule: ((Event, DateInterval, EditScope) -> Void)?
    let onDelete: ((Event, EditScope) -> Void)?
    let onCreate: ((DateInterval) -> Void)?
    let onCopy: ((Event, DateInterval) -> Void)?

    @Environment(\.calendarUndo) private var undo
    @State private var editor = CalendarEditor()
    @State private var pending: Pending?
    @FocusState private var focused: Bool

    enum Pending: Identifiable {
        case reschedule(Event, DateInterval)
        case delete(Event)

        var id: String {
            switch self {
            case .reschedule(let event, _): "move-\(event.id)"
            case .delete(let event): "delete-\(event.id)"
            }
        }

        var title: String {
            switch self {
            case .reschedule: String(localized: "This is a repeating event. Change which events?", bundle: .module)
            case .delete: String(localized: "This is a repeating event. Delete which events?", bundle: .module)
            }
        }
    }

    func body(content: Content) -> some View {
        content
            .environment(\.calendarEditor, editor)
            #if !os(watchOS)
            .focusable()
            .focusEffectDisabled()
            .focused($focused)
            .onKeyPress(keys: [.delete, .deleteForward]) { _ in
                guard let event = editor.selectedEvent as? Event, onDelete != nil else { return .ignored }
                request(.delete(event))
                return .handled
            }
            .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow]) { press in
                guard let event = editor.selectedEvent as? Event, onReschedule != nil else { return .ignored }
                let original = DateInterval(start: event.start, end: max(event.end, event.start))
                let moved: DateInterval
                switch press.key {
                case .upArrow where !event.isAllDay: moved = Timetable.moved(original, by: -snap, snap: snap, calendar: editor.calendar)
                case .downArrow where !event.isAllDay: moved = Timetable.moved(original, by: snap, snap: snap, calendar: editor.calendar)
                case .leftArrow: moved = Timetable.moved(original, byDays: -1, calendar: editor.calendar)
                case .rightArrow: moved = Timetable.moved(original, byDays: 1, calendar: editor.calendar)
                default: return .ignored
                }
                request(.reschedule(event, moved))
                return .handled
            }
            .onKeyPress(.escape) {
                guard editor.selectedID != nil else { return .ignored }
                editor.select(nil, id: nil)
                return .handled
            }
            #endif
            #if os(macOS)
            .onCopyCommand { copySelected() }
            .onCutCommand { cutSelected() }
            .onPasteCommand(of: [.plainText]) { _ in paste() }
            #endif
            .background { shortcuts }
            .onAppear(perform: configure)
            .onChange(of: selection) { _, id in
                if editor.selectedID != id.map(AnyHashable.init) {
                    editor.selectedID = id.map(AnyHashable.init)
                    if id == nil { editor.selectedEvent = nil }
                }
            }
            .confirmationDialog(pending?.title ?? "", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                                titleVisibility: .visible, presenting: pending) { action in
                ForEach([EditScope.thisEvent, .thisAndFollowing, .allEvents], id: \.self) { scope in
                    Button(Self.label(for: scope), role: isDelete(action) ? .destructive : nil) { perform(action, scope) }
                }
                Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
            }
    }

    private func configure() {
        editor.snap = snap
        editor.canReschedule = onReschedule != nil
        editor.canDelete = onDelete != nil
        editor.canCreate = onCreate != nil
        editor.selectedID = selection.map(AnyHashable.init)
        editor.reschedule = { value, interval in
            guard let event = value as? Event else { return }
            request(.reschedule(event, interval))
        }
        editor.delete = { value in
            guard let event = value as? Event else { return }
            request(.delete(event))
        }
        editor.create = { interval in
            recordingUndo(undo, String(localized: "New Event", bundle: .module)) { onCreate?(interval) }
        }
        editor.canCopy = onCopy != nil
        editor.copy = { value in if value is Event { editor.clipboard = value } }
        editor.cut = { value in
            guard let event = value as? Event else { return }
            editor.clipboard = event
            request(.delete(event))
        }
        editor.duplicate = { value in
            guard let event = value as? Event else { return }
            recordingUndo(undo, String(localized: "Duplicate Event", bundle: .module)) {
                onCopy?(event, DateInterval(start: event.start, end: max(event.end, event.start)))
            }
        }
        editor.paste = { paste() }
        editor.selectionChanged = { id in
            selection = id?.base as? Event.ID
            #if !os(watchOS)
            if id != nil { focused = true }
            #endif
        }
    }

    // MARK: - Copy and paste

    /// Keyboard shortcuts with no menu item of their own to hang on:
    /// duplicate everywhere, and copy, cut and paste where there is no Edit menu.
    @ViewBuilder private var shortcuts: some View {
        #if os(macOS) || os(iOS) || os(visionOS)
        ZStack {
            Button(String(localized: "Duplicate", bundle: .module)) { if let event = editor.selectedEvent { editor.duplicate(event) } }
                .keyboardShortcut("d", modifiers: .command)
            #if !os(macOS)
            Button(String(localized: "Copy", bundle: .module)) { _ = copySelected() }.keyboardShortcut("c", modifiers: .command)
            Button(String(localized: "Cut", bundle: .module)) { _ = cutSelected() }.keyboardShortcut("x", modifiers: .command)
            Button(String(localized: "Paste", bundle: .module)) { paste() }.keyboardShortcut("v", modifiers: .command)
            #endif
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .disabled(onCopy == nil && onDelete == nil)
        #endif
    }

    @discardableResult
    private func copySelected() -> [NSItemProvider] {
        guard let event = editor.selectedEvent as? Event else { return [] }
        editor.clipboard = event
        return [NSItemProvider(object: Spoken.when(event, calendar: editor.calendar) as NSString)]
    }

    @discardableResult
    private func cutSelected() -> [NSItemProvider] {
        let items = copySelected()
        if let event = editor.selectedEvent as? Event, onDelete != nil { request(.delete(event)) }
        return items
    }

    /// The copied event, landed on the time or day last clicked: a timed
    /// event keeps its length (and, landing on a whole day, its time of day);
    /// an all-day event keeps its days.
    private func paste() {
        guard let event = editor.clipboard as? Event, let onCopy else { return }
        let original = DateInterval(start: event.start, end: max(event.end, event.start))
        let calendar = editor.calendar
        let landing: DateInterval
        if let target = editor.pasteTarget {
            if event.isAllDay || target.isDay {
                let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: original.start),
                                                   to: calendar.startOfDay(for: target.date)).day ?? 0
                landing = Timetable.moved(original, byDays: days, calendar: calendar)
            } else {
                landing = DateInterval(start: target.date, duration: original.duration)
            }
        } else {
            landing = original
        }
        recordingUndo(undo, String(localized: "Paste Event", bundle: .module)) { onCopy(event, landing) }
    }

    private func request(_ action: Pending) {
        let event: Event
        switch action {
        case .reschedule(let e, _): event = e
        case .delete(let e): event = e
        }
        if event.isRecurring { pending = action } else { perform(action, .thisEvent) }
    }

    private func perform(_ action: Pending, _ scope: EditScope) {
        switch action {
        case .reschedule(let event, let interval):
            let name = interval.duration == event.end.timeIntervalSince(event.start)
                ? String(localized: "Move Event", bundle: .module) : String(localized: "Resize Event", bundle: .module)
            recordingUndo(undo, name) { onReschedule?(event, interval, scope) }
        case .delete(let event):
            recordingUndo(undo, String(localized: "Delete Event", bundle: .module)) { onDelete?(event, scope) }
            if editor.isSelected(event.id) { editor.select(nil, id: nil) }
        }
        pending = nil
    }

    private func isDelete(_ action: Pending) -> Bool {
        if case .delete = action { return true }
        return false
    }

    static func label(for scope: EditScope) -> String {
        switch scope {
        case .thisEvent: String(localized: "This Event", bundle: .module)
        case .thisAndFollowing: String(localized: "This and Following Events", bundle: .module)
        case .allEvents: String(localized: "All Events", bundle: .module)
        }
    }
}

