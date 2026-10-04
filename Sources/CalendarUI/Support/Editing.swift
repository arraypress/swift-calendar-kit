//
//  Editing.swift
//  CalendarUI
//
//  Selecting, moving, resizing, creating and deleting, for every calendar
//  view inside `.calendarEditing(...)`. The views never change your data:
//  they say what the user did, already snapped and — for repeating events —
//  with the scope the user picked, and your closures apply it.
//

import SwiftUI

/// The shared editing state the views read: what is selected, what is being
/// dragged, and where to send the result. Type-erased so one modifier can
/// serve every view; the typed side lives in ``EditingHost``.
@MainActor @Observable
final class CalendarEditor {
    var selectedID: AnyHashable?
    var selectedEvent: Any?
    var draggingID: AnyHashable?
    var snap: TimeInterval = 15 * 60
    /// The calendar the views on screen work in, for keyboard day moves.
    var calendar: Calendar = .current
    var canReschedule = false
    var canDelete = false
    var canCreate = false
    var reschedule: (Any, DateInterval) -> Void = { _, _ in }
    var delete: (Any) -> Void = { _ in }
    var create: (DateInterval) -> Void = { _ in }
    var selectionChanged: (AnyHashable?) -> Void = { _ in }

    func select(_ event: Any?, id: AnyHashable?) {
        selectedEvent = event
        selectedID = id
        selectionChanged(id)
    }

    func isSelected<ID: Hashable>(_ id: ID) -> Bool { selectedID == AnyHashable(id) }
    func isDragging<ID: Hashable>(_ id: ID) -> Bool { draggingID == AnyHashable(id) }
}

private struct CalendarEditorKey: EnvironmentKey {
    static let defaultValue: CalendarEditor? = nil
}

extension EnvironmentValues {
    var calendarEditor: CalendarEditor? {
        get { self[CalendarEditorKey.self] }
        set { self[CalendarEditorKey.self] = newValue }
    }
}

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
    /// Leave a closure out and that edit is off: no `onReschedule`, no dragging.
    ///
    /// - Parameters:
    ///   - selection: the selected event's id, or nil.
    ///   - snapping: what drags snap to, in seconds; 15 minutes by default.
    public func calendarEditing<Event: CalendarEvent>(
        _ type: Event.Type = Event.self,
        selection: Binding<Event.ID?>,
        snapping: TimeInterval = 15 * 60,
        onReschedule: ((Event, DateInterval, EditScope) -> Void)? = nil,
        onDelete: ((Event, EditScope) -> Void)? = nil,
        onCreate: ((DateInterval) -> Void)? = nil
    ) -> some View where Event.ID: Sendable {
        modifier(EditingHost(selection: selection, snap: snapping, onReschedule: onReschedule,
                             onDelete: onDelete, onCreate: onCreate))
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
            case .reschedule: String(localized: "This is a repeating event. Change which events?")
            case .delete: String(localized: "This is a repeating event. Delete which events?")
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
                Button("Cancel", role: .cancel) {}
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
            recordingUndo(undo, String(localized: "New Event")) { onCreate?(interval) }
        }
        editor.selectionChanged = { id in
            selection = id?.base as? Event.ID
            #if !os(watchOS)
            if id != nil { focused = true }
            #endif
        }
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
                ? String(localized: "Move Event") : String(localized: "Resize Event")
            recordingUndo(undo, name) { onReschedule?(event, interval, scope) }
        case .delete(let event):
            recordingUndo(undo, String(localized: "Delete Event")) { onDelete?(event, scope) }
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
        case .thisEvent: String(localized: "This Event")
        case .thisAndFollowing: String(localized: "This and Following Events")
        case .allEvents: String(localized: "All Events")
        }
    }
}

// MARK: - The drag gesture

/// Where a drag began and how far it has gone, in the view's own space.
struct DragStep {
    var start: CGPoint
    var translation: CGSize
}

extension View {

    /// A drag that does not fight scrolling: immediate with a mouse or
    /// trackpad, press-and-hold first on a touch screen. Absent on Apple TV.
    ///
    /// - Parameter space: where the translation is measured. A handle that
    ///   moves as it is dragged — a resize edge — must use `.global`: in its
    ///   own moving space each step of growth would change the next reading,
    ///   and the edge would judder.
    func editDrag(enabled: Bool = true, in space: CoordinateSpace = .local,
                  onChanged: @escaping (DragStep) -> Void, onEnded: @escaping (DragStep) -> Void) -> some View {
        modifier(EditDrag(enabled: enabled, space: space, onChanged: onChanged, onEnded: onEnded))
    }

    /// Shows a resize cursor over a handle on the Mac. Sets rather than
    /// pushes, so a handle that slides out from under the pointer mid-drag
    /// cannot leave the cursor stack unbalanced.
    func resizeCursor(vertical: Bool) -> some View {
        #if os(macOS)
        onHover { inside in
            (inside ? (vertical ? NSCursor.resizeUpDown : NSCursor.resizeLeftRight) : NSCursor.arrow).set()
        }
        #else
        self
        #endif
    }
}

private struct EditDrag: ViewModifier {

    let enabled: Bool
    let space: CoordinateSpace
    let onChanged: (DragStep) -> Void
    let onEnded: (DragStep) -> Void

    func body(content: Content) -> some View {
        #if os(macOS)
        content.gesture(
            DragGesture(minimumDistance: 4, coordinateSpace: space)
                .onChanged { onChanged(DragStep(start: $0.startLocation, translation: $0.translation)) }
                .onEnded { onEnded(DragStep(start: $0.startLocation, translation: $0.translation)) },
            including: enabled ? .all : .subviews
        )
        #elseif os(iOS) || os(visionOS)
        content.gesture(
            LongPressGesture(minimumDuration: 0.3)
                .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: space))
                .onChanged { value in
                    if case .second(true, let drag?) = value {
                        onChanged(DragStep(start: drag.startLocation, translation: drag.translation))
                    }
                }
                .onEnded { value in
                    if case .second(true, let drag?) = value {
                        onEnded(DragStep(start: drag.startLocation, translation: drag.translation))
                    }
                },
            including: enabled ? .all : .subviews
        )
        #else
        content
        #endif
    }
}
