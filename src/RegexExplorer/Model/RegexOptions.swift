// Copyright © 2026 Robert Hedin

import Foundation

/// Optional settings applied when a saved regex is compiled.
struct RegexOptions: Codable, Hashable, Sendable {
    /// Letters match regardless of case.
    var ignoresCase = false
    /// `^` and `$` match at the start and end of every line, not just the whole text.
    var anchorsMatchLineEndings = false
    /// `.` also matches newline characters.
    var dotMatchesNewlines = false
    /// Whitespace in the pattern is ignored and `#` starts a comment.
    var allowsExtendedSyntax = false
    /// `\b` uses simple word-character transitions instead of Unicode word rules.
    var usesSimpleWordBoundaries = false

    init(
        ignoresCase: Bool = false,
        anchorsMatchLineEndings: Bool = false,
        dotMatchesNewlines: Bool = false,
        allowsExtendedSyntax: Bool = false,
        usesSimpleWordBoundaries: Bool = false
    ) {
        self.ignoresCase = ignoresCase
        self.anchorsMatchLineEndings = anchorsMatchLineEndings
        self.dotMatchesNewlines = dotMatchesNewlines
        self.allowsExtendedSyntax = allowsExtendedSyntax
        self.usesSimpleWordBoundaries = usesSimpleWordBoundaries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ignoresCase = try container.decodeIfPresent(Bool.self, forKey: .ignoresCase) ?? false
        anchorsMatchLineEndings = try container.decodeIfPresent(Bool.self, forKey: .anchorsMatchLineEndings) ?? false
        dotMatchesNewlines = try container.decodeIfPresent(Bool.self, forKey: .dotMatchesNewlines) ?? false
        allowsExtendedSyntax = try container.decodeIfPresent(Bool.self, forKey: .allowsExtendedSyntax) ?? false
        usesSimpleWordBoundaries = try container.decodeIfPresent(Bool.self, forKey: .usesSimpleWordBoundaries) ?? false
    }
}
