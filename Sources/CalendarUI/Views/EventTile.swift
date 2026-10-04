//
//  EventTile.swift
//  CalendarUI
//

import SwiftUI

/// The standard event tile: a tinted card with a coloured stripe down its
/// leading edge. Use it inside a custom tile closure to keep the look and
/// change only the content.
public struct EventTile<Content: View>: View {

    @Environment(\.calendarStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    private let tint: Color
    private let content: Content

    /// A tile in a colour, holding any content.
    public init(tint: Color, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: style.tileCornerRadius, style: .continuous)
        HStack(alignment: .top, spacing: 5) {
            Capsule()
                .fill(tint)
                .frame(width: 3.5)
                .padding(.vertical, 4)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.vertical, 4)
        }
        .padding(.leading, 3)
        .padding(.trailing, 4)
        .background(tint.opacity(colorScheme == .dark ? 0.28 : 0.16), in: shape)
        .background(.background, in: shape)
        .overlay(shape.strokeBorder(tint.opacity(0.25), lineWidth: 0.5))
        .clipShape(shape)
        .contentShape(shape)
    }
}

extension EventTile where Content == EventTileLabel {

    /// A tile showing a title, a second line such as its time, and a ↻
    /// badge when the event repeats.
    public init(_ title: String, subtitle: String? = nil, tint: Color, repeats: Bool = false) {
        self.init(tint: tint) { EventTileLabel(title: title, subtitle: subtitle, repeats: repeats) }
    }
}

/// A tile's title and an optional second line, as the standard tile shows them.
public struct EventTileLabel: View {

    let title: String
    let subtitle: String?
    var repeats = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                if repeats {
                    Spacer(minLength: 0)
                    RepeatBadge()
                }
            }
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
