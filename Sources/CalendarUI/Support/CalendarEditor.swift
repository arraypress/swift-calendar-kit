//
//  CalendarEditor.swift
//  CalendarUI
//
//  What is selected, what is being dragged, and where edits go — shared by every view inside `.calendarEditing(...)`.
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
    var canCopy = false
    /// Where a paste lands: the time or day last clicked on.
    var pasteTarget: PasteTarget?
    /// The event last copied or cut, inside this calendar.
    var clipboard: Any?
    var reschedule: (Any, DateInterval) -> Void = { _, _ in }
    var delete: (Any) -> Void = { _ in }
    var create: (DateInterval) -> Void = { _ in }
    var copy: (Any) -> Void = { _ in }
    var cut: (Any) -> Void = { _ in }
    var duplicate: (Any) -> Void = { _ in }
    var paste: () -> Void = {}
    var selectionChanged: (AnyHashable?) -> Void = { _ in }

    func select(_ event: Any?, id: AnyHashable?) {
        selectedEvent = event
        selectedID = id
        selectionChanged(id)
    }

    func isSelected<ID: Hashable>(_ id: ID) -> Bool { selectedID == AnyHashable(id) }
    func isDragging<ID: Hashable>(_ id: ID) -> Bool { draggingID == AnyHashable(id) }
}

/// A time (or a whole day) a paste should land on.
struct PasteTarget {
    var date: Date
    var isDay: Bool
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
