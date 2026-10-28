// Copyright © 2026 Robert Hedin
// All Rights Reserved.

import Foundation

/// One capture group within a match. Group 0 (the whole match) is not included.
struct CaptureGroup: Hashable, Sendable {
    /// 1-based group number, in the order the groups open in the pattern.
    let number: Int
    /// The group's name, for named groups such as `(?<year>\d{4})`.
    let name: String?
    /// Where the group matched in the text, or `nil` if it did not take part in the match.
    let range: Range<String.Index>?
}

/// One match of a regex in a piece of text.
struct RegexMatch: Hashable, Sendable {
    let range: Range<String.Index>
    let groups: [CaptureGroup]
}

/// The result of applying a pattern to some text.
enum RegexEvaluation: Equatable, Sendable {
    /// The pattern is empty, so there is nothing to match.
    case noPattern
    /// The pattern does not compile. The message describes why.
    case invalidPattern(String)
    /// The matches found. `truncated` is true when more matches exist than were returned.
    case matches([RegexMatch], truncated: Bool)
}

/// Compiles patterns with ``RegexOptions`` and finds their matches using Swift Regex.
enum RegexEvaluator {
    /// The most matches reported for one evaluation, to keep highlighting responsive.
    static let defaultMatchLimit = 1_000

    static func evaluate(
        pattern: String,
        options: RegexOptions,
        in text: String,
        matchLimit: Int = defaultMatchLimit
    ) -> RegexEvaluation {
        guard !pattern.isEmpty else { return .noPattern }

        let regex: Regex<AnyRegexOutput>
        do {
            regex = try makeRegex(pattern: pattern, options: options)
        } catch {
            return .invalidPattern(String(describing: error))
        }

        let found = text.matches(of: regex)
        let matches = found.prefix(matchLimit).map { match in
            let groups = match.output.dropFirst().enumerated().map { offset, element in
                CaptureGroup(number: offset + 1, name: element.name, range: element.range)
            }
            return RegexMatch(range: match.range, groups: groups)
        }
        return .matches(matches, truncated: found.count > matchLimit)
    }

    static func makeRegex(pattern: String, options: RegexOptions) throws -> Regex<AnyRegexOutput> {
        // Swift Regex has no modifier method for extended syntax, so use the inline flag.
        var regex = try Regex(options.allowsExtendedSyntax ? "(?x)" + pattern : pattern)
        // Only apply options that are switched on, so inline flags in the pattern still work.
        if options.ignoresCase {
            regex = regex.ignoresCase()
        }
        if options.anchorsMatchLineEndings {
            regex = regex.anchorsMatchLineEndings()
        }
        if options.dotMatchesNewlines {
            regex = regex.dotMatchesNewlines()
        }
        if options.usesSimpleWordBoundaries {
            regex = regex.wordBoundaryKind(.simple)
        }
        return regex
    }
}
