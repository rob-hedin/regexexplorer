// Copyright © 2026 Robert Hedin

import Foundation

/// One line of the cheat sheet: a piece of regex syntax and what it means.
struct CheatSheetEntry: Hashable, Sendable {
    let token: String
    let meaning: String
}

struct CheatSheetSection: Identifiable, Hashable, Sendable {
    var id: String { title }
    let title: String
    let entries: [CheatSheetEntry]
}

/// The regex syntax reference shown in the cheat sheet window.
enum CheatSheet {
    static let sections: [CheatSheetSection] = [
        section("Characters", [
            (".", "Any character except newline"),
            (#"\d  \D"#, "Digit / not a digit"),
            (#"\w  \W"#, "Word character / not"),
            (#"\s  \S"#, "Whitespace / not"),
            (#"\t  \n"#, "Tab / newline"),
            (#"\."#, "A literal dot"),
        ]),
        section("Anchors", [
            ("^", "Start of text (or line)"),
            ("$", "End of text (or line)"),
            (#"\b"#, "Word boundary"),
            (#"\B"#, "Not a word boundary"),
            (#"\A  \z"#, "Start / end of text only"),
        ]),
        section("Classes", [
            ("[abc]", "Any of a, b or c"),
            ("[^abc]", "Anything but a, b or c"),
            ("[a-z]", "Any of a to z"),
            ("[a-z0-9]", "Ranges combine"),
        ]),
        section("Quantifiers", [
            ("*", "0 or more"),
            ("+", "1 or more"),
            ("?", "0 or 1"),
            ("{3}", "Exactly 3"),
            ("{2,5}", "2 to 5"),
            ("*?  +?", "As few as possible"),
        ]),
        section("Groups", [
            ("(abc)", "Capture group"),
            ("(?<name>abc)", "Named group"),
            ("(?:abc)", "Group, no capture"),
            ("a|b", "a or b"),
            (#"\1"#, "Same text as group 1"),
        ]),
        section("Lookahead and Flags", [
            ("(?=abc)", "Followed by abc"),
            ("(?!abc)", "Not followed by abc"),
            ("(?i)", "Ignore case from here"),
            ("(?m)", "^ $ match each line"),
            ("(?s)", ". matches newlines"),
            ("(?x)", "Ignore whitespace"),
        ]),
        section("Replacement", [
            ("$0", "The whole match"),
            ("$1", "Group 1"),
            ("${name}", "The group called name"),
            ("$$", "A literal $"),
        ]),
    ]

    /// The sections, keeping only entries whose token or meaning contains `query`.
    /// A section whose title matches keeps all its entries.
    static func sections(matching query: String) -> [CheatSheetSection] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return sections }
        return sections.compactMap { section in
            if section.title.localizedStandardContains(query) { return section }
            let entries = section.entries.filter {
                $0.token.localizedStandardContains(query) || $0.meaning.localizedStandardContains(query)
            }
            return entries.isEmpty ? nil : CheatSheetSection(title: section.title, entries: entries)
        }
    }

    private static func section(_ title: String, _ entries: [(String, String)]) -> CheatSheetSection {
        CheatSheetSection(title: title, entries: entries.map { CheatSheetEntry(token: $0.0, meaning: $0.1) })
    }
}
