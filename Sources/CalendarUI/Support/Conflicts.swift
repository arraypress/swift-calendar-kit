//
//  Conflicts.swift
//  CalendarUI
//
//  Warning outlines on events that clash: overlapping, or closer together
//  than a buffer, among events that compete for the same thing.
//

import SwiftUI

/// Finds the clashing events among whatever a view is showing.
struct ConflictRule: Sendable {
    let find: @MainActor @Sendable ([Any]) -> Set<AnyHashable>
}

private struct ConflictRuleKey: EnvironmentKey {
    static let defaultValue: ConflictRule? = nil
}

/// The clashing events' ids. Built and read on the main actor only.
struct ConflictSet: @unchecked Sendable {
    var ids: Set<AnyHashable> = []
}

private struct ConflictsKey: EnvironmentKey {
    static let defaultValue = ConflictSet()
}

extension EnvironmentValues {
    var conflictRule: ConflictRule? {
        get { self[ConflictRuleKey.self] }
        set { self[ConflictRuleKey.self] = newValue }
    }

    /// The clashing events' ids, worked out once per timeline.
    var conflicts: ConflictSet {
        get { self[ConflictsKey.self] }
        set { self[ConflictsKey.self] = newValue }
    }
}

extension View {

    /// Outlines timed events that overlap another, or come within `buffer`
    /// of one, in every calendar view inside — a double-booked plumber, a
    /// clean with no time to get across town.
    ///
    /// - Parameter sameGroup: whether two events compete: the same property,
    ///   room or person. Events that do not are never flagged against each other.
    public func calendarConflicts<Event: CalendarEvent>(
        _ type: Event.Type = Event.self, buffer: TimeInterval = 0,
        sameGroup: @escaping @Sendable (Event, Event) -> Bool = { _, _ in true }
    ) -> some View where Event: Sendable, Event.ID: Sendable {
        environment(\.conflictRule, ConflictRule { values in
            Set(Timetable.conflicts(values.compactMap { $0 as? Event }, buffer: buffer, sameGroup: sameGroup).map(AnyHashable.init))
        })
    }

    /// The orange outline and badge on a clashing tile.
    func conflictOutline<ID: Hashable>(_ id: ID) -> some View {
        modifier(ConflictOutline(id: AnyHashable(id)))
    }
}

private struct ConflictOutline: ViewModifier {

    @Environment(\.conflicts) private var conflicts
    @Environment(\.calendarStyle) private var style
    let id: AnyHashable

    func body(content: Content) -> some View {
        let clashing = conflicts.ids.contains(id)
        content
            .overlay {
                if clashing {
                    RoundedRectangle(cornerRadius: style.tileCornerRadius, style: .continuous)
                        .strokeBorder(Color.orange, style: StrokeStyle(lineWidth: 1.5, dash: [4, 2]))
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if clashing {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                        .padding(3)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityHint(clashing ? Text("Conflicts with another event") : Text(""))
    }
}
