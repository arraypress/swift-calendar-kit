//
//  TimedDrag.swift
//  CalendarUI
//
//  Moving a timed tile by dragging it, and resizing it by its bottom edge.
//

import SwiftUI

/// Moving a timed tile by dragging it, and resizing it by its bottom edge.
/// The tile follows the pointer in snapped steps and shows its new time;
/// letting go hands the new interval to the editor.
struct TimedDrag<Event: CalendarEvent>: ViewModifier {

    @Environment(\.calendarEditor) private var editor
    let event: Event
    let height: CGFloat
    let columnWidth: CGFloat
    let days: ClosedRange<Int>
    let secondsPerPoint: TimeInterval
    let calendar: Calendar

    @State private var move: CGSize?
    @State private var stretch: CGFloat?

    func body(content: Content) -> some View {
        let original = DateInterval(start: event.start, end: max(event.end, event.start))
        let snap = editor?.snap ?? 900
        let snapPoints = CGFloat(snap / secondsPerPoint)
        let dayStep = move.map { min(max(Int(($0.width / max(columnWidth, 1)).rounded()), days.lowerBound), days.upperBound) } ?? 0
        let rawSeconds = TimeInterval(move?.height ?? 0) * secondsPerPoint
        let preview = move.map { _ in Timetable.moved(original, days: dayStep, by: rawSeconds, snap: snap, calendar: calendar) }
        let resized = stretch.map { Timetable.resized(original, end: original.end.addingTimeInterval(TimeInterval($0) * secondsPerPoint),
                                                      snap: snap, calendar: calendar) }
        let canEdit = editor?.canReschedule == true

        content
            .frame(height: max(height + (resized.map { CGFloat(($0.duration - original.duration) / secondsPerPoint) } ?? 0), snapPoints, 4),
                   alignment: .top)
            .overlay(alignment: .topTrailing) {
                if let shown = preview ?? resized {
                    Text(calendar.timeRange(shown.start, shown.end))
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(.regularMaterial, in: Capsule())
                        .offset(y: -18)
                        .fixedSize()
                }
            }
            .overlay(alignment: .bottom) {
                if canEdit, editor?.isSelected(event.id) == true {
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: 28, height: 5)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle().inset(by: -6))
                        .editDrag(in: .global) { step in
                            stretch = step.translation.height
                            editor?.draggingID = AnyHashable(event.id)
                        } onEnded: { _ in
                            if let resized, resized != original { editor?.reschedule(event, resized) }
                            stretch = nil
                            editor?.draggingID = nil
                        }
                        .resizeCursor(vertical: true)
                }
            }
            .offset(x: CGFloat(dayStep) * columnWidth, y: verticalShift(preview, from: original))
            .opacity(move == nil ? 1 : 0.9)
            .shadow(color: .black.opacity(move == nil ? 0 : 0.25), radius: move == nil ? 0 : 6, y: 3)
            .editDrag(enabled: canEdit) { step in
                move = step.translation
                editor?.draggingID = AnyHashable(event.id)
                if editor?.isSelected(event.id) == false { editor?.select(event, id: AnyHashable(event.id)) }
            } onEnded: { _ in
                if let preview, preview != original { editor?.reschedule(event, preview) }
                move = nil
                editor?.draggingID = nil
            }
    }

    /// How far down the previewed start sits from the original, in points.
    private func verticalShift(_ preview: DateInterval?, from original: DateInterval) -> CGFloat {
        guard let preview else { return 0 }
        return CGFloat((timeOfDay(preview.start) - timeOfDay(original.start)) / secondsPerPoint)
    }

    /// Seconds since the start of an instant's day, so a move across days
    /// previews only its change in time of day vertically.
    private func timeOfDay(_ date: Date) -> TimeInterval {
        date.timeIntervalSince(calendar.startOfDay(for: date))
    }
}
