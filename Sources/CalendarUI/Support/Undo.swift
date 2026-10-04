//
//  Undo.swift
//  CalendarUI
//
//  Undo for calendar edits, by snapshot. Your edit closures can do anything
//  — skip an occurrence, split a series, add a one-off — so "move it back"
//  cannot be worked out from the edit. Restoring the collection the edit
//  changed can, whatever the edit was.
//

import SwiftUI

/// Records an edit for undo: snapshot, run, register undo and redo.
@MainActor
struct UndoHook {
    let record: (_ actionName: String, _ edit: () -> Void) -> Void
}

private struct UndoHookKey: EnvironmentKey {
    static let defaultValue: UndoHook? = nil
}

extension EnvironmentValues {
    var calendarUndo: UndoHook? {
        get { self[UndoHookKey.self] }
        set { self[UndoHookKey.self] = newValue }
    }
}

extension View {

    /// Makes every calendar edit inside undoable — Cmd-Z, the Edit menu,
    /// shake to undo — by restoring `value` to what it was before the edit.
    ///
    /// Pass the collection your edit closures change. Apply it outside
    /// `.calendarEditing(...)`:
    ///
    /// ```swift
    /// WeekView(...)
    ///     .calendarEditing(Item.self, selection: $selection, onReschedule: move, onDelete: delete)
    ///     .calendarUndo($bookings)
    /// ```
    public func calendarUndo<Value>(_ value: Binding<Value>) -> some View {
        modifier(CalendarUndo(value: value))
    }
}

/// Runs an edit through the undo hook if there is one, otherwise directly.
@MainActor
func recordingUndo(_ hook: UndoHook?, _ name: String, _ edit: () -> Void) {
    if let hook { hook.record(name, edit) } else { edit() }
}

private struct CalendarUndo<Value>: ViewModifier {

    @Environment(\.undoManager) private var undoManager
    @Binding var value: Value
    /// What the undo manager files these actions under; lives as long as the view.
    @State private var target = UndoTarget()

    func body(content: Content) -> some View {
        content.environment(\.calendarUndo, UndoHook { name, edit in
            let before = value
            edit()
            guard let undoManager else { return }
            Self.register(name, restoring: before, then: value, into: $value, undoManager: undoManager, target: target)
        })
    }

    /// Undo restores `old` and registers its own reversal — redo — which
    /// restores `new`, and so on back and forth.
    private static func register(_ name: String, restoring old: Value, then new: Value, into binding: Binding<Value>,
                                 undoManager: UndoManager, target: UndoTarget) {
        undoManager.registerUndo(withTarget: target) { target in
            MainActor.assumeIsolated {
                binding.wrappedValue = old
                register(name, restoring: new, then: old, into: binding, undoManager: undoManager, target: target)
            }
        }
        undoManager.setActionName(name)
    }
}

/// The object undo actions are registered against.
private final class UndoTarget {}
