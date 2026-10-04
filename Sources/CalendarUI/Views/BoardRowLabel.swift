//
//  BoardRowLabel.swift
//  CalendarUI
//

import SwiftUI

/// A board row's name, with how full it is and a warning for double bookings.
public struct BoardRowLabel: View {

    let name: String
    let occupancy: Double
    let clashes: Bool

    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            HStack(spacing: 6) {
                Capsule()
                    .fill(.quaternary)
                    .frame(width: 44, height: 4)
                    .overlay(alignment: .leading) {
                        Capsule().fill(.tint).frame(width: 44 * min(max(occupancy, 0), 1), height: 4)
                    }
                Text(occupancy, format: .percent.precision(.fractionLength(0)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                if clashes {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .help("Double booked")
                }
            }
        }
    }
}
