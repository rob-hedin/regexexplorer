// Copyright © 2026 Robert Hedin

import SwiftUI

/// A capture group shown as a column in the match table.
struct GroupColumn: Identifiable, Hashable {
    /// The group's number, starting at 1.
    let id: Int
    /// Position in ``MatchRow/groupValues``.
    let index: Int
    let title: String
}

/// One row of the match table.
struct MatchRow: Identifiable, Hashable {
    /// The match's number, starting at 1.
    let id: Int
    let text: String
    /// Each group's matched text, or `nil` if the group didn't take part.
    let groupValues: [String?]
    /// Character offsets of the match, such as "14–25".
    let position: String
}

/// Turns matches into what the results view displays.
enum MatchPresentation {
    private static let groupColors: [Color] = [.blue, .orange, .purple, .teal, .pink]

    static func color(forGroup number: Int) -> Color {
        groupColors[(number - 1) % groupColors.count]
    }

    /// One column per capture group. Every match of a pattern has the same groups.
    static func groupColumns(for matches: [RegexMatch]) -> [GroupColumn] {
        (matches.first?.groups ?? []).enumerated().map { index, group in
            GroupColumn(id: group.number, index: index, title: group.name ?? "Group \(group.number)")
        }
    }

    static func rows(for matches: [RegexMatch], in text: String) -> [MatchRow] {
        matches.enumerated().map { offset, match in
            let start = text.distance(from: text.startIndex, to: match.range.lowerBound)
            let end = start + text.distance(from: match.range.lowerBound, to: match.range.upperBound)
            return MatchRow(
                id: offset + 1,
                text: String(text[match.range]),
                groupValues: match.groups.map { $0.range.map { String(text[$0]) } },
                position: "\(start)–\(end)"
            )
        }
    }

    /// The text with each match on a highlighted background and each group underlined in its colour.
    static func highlightedText(_ text: String, matches: [RegexMatch]) -> AttributedString {
        var result = AttributedString(text)
        for match in matches {
            guard let matchRange = Range(match.range, in: result) else { continue }
            result[matchRange].backgroundColor = Color.yellow.opacity(0.35)
            for group in match.groups {
                guard let groupRange = group.range.flatMap({ Range($0, in: result) }) else { continue }
                result[groupRange].underlineStyle = Text.LineStyle(pattern: .solid, color: color(forGroup: group.number))
            }
        }
        return result
    }

    /// The text with the given character ranges on a highlighted background.
    static func highlighted(_ text: String, ranges: [Range<Int>]) -> AttributedString {
        var result = AttributedString(text)
        let characters = result.characters
        let count = characters.count
        for range in ranges where !range.isEmpty && range.upperBound <= count {
            let lower = characters.index(characters.startIndex, offsetBy: range.lowerBound)
            let upper = characters.index(lower, offsetBy: range.count)
            result[lower..<upper].backgroundColor = Color.accentColor.opacity(0.2)
        }
        return result
    }
}
