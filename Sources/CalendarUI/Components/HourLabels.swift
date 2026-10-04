//
//  HourLabels.swift
//  CalendarUI
//
//  The hour labels down a timeline's leading edge, in one or two zones.
//

import SwiftUI

/// The hour labels, each centred on its line.
struct HourLabels: View {

    @Environment(\.calendarStyle) private var style
    let day: Date
    let calendar: Calendar
    var secondZone: TimeZone? = nil

    var body: some View {
        let marks = Timetable.hourMarks(on: day, calendar: calendar)
        let height = height(of: day)
        let other = secondZone.map { zone -> Calendar in
            var copy = calendar
            copy.timeZone = zone
            return copy
        }
        ZStack(alignment: .topTrailing) {
            Color.clear
            ForEach(marks) { mark in
                HStack(spacing: 4) {
                    if let other {
                        Text(mark.hour == 0 ? abbreviation(other.timeZone) : other.hourLabel(mark.date))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    Text(mark.hour == 0 ? (other == nil ? "" : abbreviation(calendar.timeZone)) : calendar.hourLabel(mark.date))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: other == nil ? 0 : style.hourLabelWidth * 0.8, alignment: .trailing)
                }
                    .font(.caption2)
                    .padding(.trailing, 6)
                    .padding(.top, max(mark.position * height - 7, 0))  // padding, not offset: scrollTo needs the real frame
                    .id(mark.hour)
            }
        }
        .frame(height: height)
    }

    private func height(of day: Date) -> CGFloat {
        CGFloat(calendar.dateInterval(of: .day, for: day)!.duration / 3600) * style.hourHeight
    }

    /// "BST", or the zone's name when it has no short form here.
    private func abbreviation(_ zone: TimeZone) -> String {
        zone.abbreviation(for: day) ?? zone.identifier
    }
}
