//
//  Swipe.swift
//  CalendarUI
//
//  Swiping between periods. Apple TV has no drag gesture; there the arrow
//  buttons are the only way, which is how a remote works anyway.
//

import SwiftUI

extension View {

    /// Steps forward on a swipe left (or up, when `vertical` is allowed) and
    /// back on a swipe right (or down).
    func swipeToStep(vertical: Bool = false, _ step: @escaping (Int) -> Void) -> some View {
        #if os(tvOS)
        return self
        #else
        return gesture(DragGesture(minimumDistance: 30).onEnded { drag in
            let x = drag.translation.width, y = drag.translation.height
            if abs(x) > abs(y) * 1.5 {
                step(x < 0 ? 1 : -1)
            } else if vertical && abs(y) > abs(x) * 1.5 {
                step(y < 0 ? 1 : -1)
            }
        })
        #endif
    }
}
