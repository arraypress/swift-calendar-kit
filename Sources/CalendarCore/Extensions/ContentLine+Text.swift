//
//  ContentLine+Text.swift
//  CalendarCore
//

import Foundation

extension ContentLine {

    /// The value as text, unescaped: `Viewing, Flat 3` from `Viewing\\, Flat 3`.
    var textValue: String { ICSLines.text(self) }
}
