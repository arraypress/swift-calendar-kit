//
//  StepButton.swift
//  CalendarUI
//

import SwiftUI

/// A small chevron that steps a period back or forward.
struct StepButton: View {

    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel(systemImage.contains("left") || systemImage.contains("up") ? Text("Previous", bundle: .module) : Text("Next", bundle: .module))
    }
}
