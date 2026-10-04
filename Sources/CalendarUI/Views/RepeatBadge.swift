//
//  RepeatBadge.swift
//  CalendarUI
//

import SwiftUI

/// The ↻ that marks a repeating event wherever it appears.
public struct RepeatBadge: View {

    public init() {}

    public var body: some View {
        Image(systemName: "repeat")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text("Repeats", bundle: .module))
    }
}
