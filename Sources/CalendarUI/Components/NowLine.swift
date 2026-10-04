//
//  NowLine.swift
//  CalendarUI
//
//  The line marking the current time on today's column.
//

import SwiftUI

/// A line at the current time, kept current.
struct NowLine: View {

    @Environment(\.calendarStyle) private var style
    let day: DateInterval
    let height: CGFloat

    var body: some View {
        TimelineView(.everyMinute) { context in
            if day.contains(context.date) {
                HStack(spacing: 0) {
                    Circle().fill(style.todayColor).frame(width: 7, height: 7)
                    Rectangle().fill(style.todayColor).frame(height: 1.5)
                }
                .offset(x: -3.5, y: context.date.timeIntervalSince(day.start) / day.duration * height - 3.5)
            }
        }
        .allowsHitTesting(false)
    }
}
