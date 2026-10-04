//
//  EditDrag.swift
//  CalendarUI
//
//  A drag that does not fight scrolling, and the resize cursor.
//

import SwiftUI

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
