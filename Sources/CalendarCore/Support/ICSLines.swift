//
//  ICSLines.swift
//  CalendarCore
//
//  RFC 5545 §3.1 content lines: unfolding, splitting name, parameters and
//  value (quotes respected), and unescaping text.
//

import Foundation

enum ICSLines {

    /// Lines joined back where they were folded: a line starting with a space
    /// or tab continues the one before.
    static func unfold(_ text: String) -> [String] {
        var lines: [String] = []
        for line in text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n") {
            if let first = line.first, first == " " || first == "\t", !lines.isEmpty {
                lines[lines.count - 1] += line.dropFirst()
            } else if !line.isEmpty {
                lines.append(line)
            }
        }
        return lines
    }

    /// A line split into name, parameters and value; nil without a colon.
    static func parse(_ line: String) -> ContentLine? {
        var name = "", parameters: [String: String] = [:], current = "", key = ""
        var inQuotes = false, inName = true, seenColon = false
        var valueStart = line.endIndex
        for index in line.indices {
            let character = line[index]
            if character == "\"" { inQuotes.toggle(); continue }
            if inQuotes { current.append(character); continue }
            switch character {
            case ";":
                if inName { name = current; inName = false } else if !key.isEmpty { parameters[key.uppercased()] = current }
                current = ""; key = ""
            case "=" where !inName && key.isEmpty:
                key = current; current = ""
            case ":":
                if inName { name = current } else if !key.isEmpty { parameters[key.uppercased()] = current }
                valueStart = line.index(after: index)
                seenColon = true
            default:
                current.append(character)
            }
            if seenColon { break }
        }
        guard seenColon, !name.isEmpty else { return nil }
        return ContentLine(name: name.uppercased(), parameters: parameters, value: String(line[valueStart...]), raw: line)
    }

    /// RFC 5545 §3.3.11 text, unescaped.
    static func text(_ line: ContentLine) -> String {
        var result = "", escaping = false
        for character in line.value {
            if escaping {
                switch character {
                case "n", "N": result.append("\n")
                default: result.append(character)
                }
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                result.append(character)
            }
        }
        return result
    }
}
