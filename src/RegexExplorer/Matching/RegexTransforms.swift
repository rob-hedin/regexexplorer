// Copyright © 2026 Robert Hedin
// All Rights Reserved.

import Foundation

/// A parsed replacement template such as `<${name}>`.
///
/// `$0` is the whole match, `$1`… or `${1}`… a numbered group, `${name}` a named group,
/// and `$$` a literal `$`. A group that didn't take part in the match expands to nothing.
/// Anything else, such as `$x` or a reference to a group that doesn't exist, is kept as typed.
struct ReplacementTemplate: Equatable, Sendable {
    enum Segment: Equatable, Sendable {
        case literal(String)
        /// A numbered group; 0 is the whole match.
        case group(Int)
        case namedGroup(String)
    }

    let segments: [Segment]

    /// Parses `template` for a pattern with `groupCount` capture groups named `groupNames`.
    init(_ template: String, groupCount: Int, groupNames: Set<String>) {
        var segments: [Segment] = []
        var literal = ""
        func emit(_ segment: Segment) {
            if !literal.isEmpty {
                segments.append(.literal(literal))
                literal = ""
            }
            segments.append(segment)
        }

        var index = template.startIndex
        while index < template.endIndex {
            let character = template[index]
            let next = template.index(after: index)
            guard character == "$", next < template.endIndex else {
                literal.append(character)
                index = next
                continue
            }

            if template[next] == "$" {
                literal.append("$")
                index = template.index(after: next)
                continue
            }

            if template[next] == "{", let close = template[next...].firstIndex(of: "}") {
                let key = String(template[template.index(after: next)..<close])
                if let number = Int(key), number <= groupCount, number >= 0 {
                    emit(.group(number))
                    index = template.index(after: close)
                    continue
                }
                if groupNames.contains(key) {
                    emit(.namedGroup(key))
                    index = template.index(after: close)
                    continue
                }
            }

            // Take as many digits as still name an existing group, so `$12` is group 1
            // followed by "2" when there are fewer than 12 groups.
            var digitEnd = next
            var number = 0
            var longest: (number: Int, end: String.Index)?
            while digitEnd < template.endIndex, template[digitEnd].isASCII, let digit = template[digitEnd].wholeNumberValue {
                number = number * 10 + digit
                digitEnd = template.index(after: digitEnd)
                guard number <= groupCount else { break }
                longest = (number, digitEnd)
            }
            if let longest {
                emit(.group(longest.number))
                index = longest.end
                continue
            }

            literal.append("$")
            index = next
        }
        if !literal.isEmpty {
            segments.append(.literal(literal))
        }
        self.segments = segments
    }

    /// Parses `template` using the groups of `match`.
    init(_ template: String, for match: RegexMatch) {
        self.init(template, groupCount: match.groups.count, groupNames: Set(match.groups.compactMap(\.name)))
    }

    /// The replacement text for one match.
    func expand(for match: RegexMatch, in text: String) -> String {
        segments.map { segment in
            switch segment {
            case .literal(let literal):
                literal
            case .group(0):
                String(text[match.range])
            case .group(let number):
                match.groups[number - 1].range.map { String(text[$0]) } ?? ""
            case .namedGroup(let name):
                match.groups.first { $0.name == name }?.range.map { String(text[$0]) } ?? ""
            }
        }
        .joined()
    }
}

/// The text after replacing every match.
struct ReplacementResult: Equatable, Sendable {
    let text: String
    /// Where each replacement landed in ``text``, as character offsets.
    let replacedRanges: [Range<Int>]
}

enum RegexReplacer {
    static func replace(in text: String, matches: [RegexMatch], template: String) -> ReplacementResult {
        var output = ""
        var outputLength = 0
        var replacedRanges: [Range<Int>] = []
        var copiedUpTo = text.startIndex

        // Every match of a pattern has the same groups, so one parse serves them all.
        let parsed = matches.first.map { ReplacementTemplate(template, for: $0) }
        for match in matches {
            let unchanged = text[copiedUpTo..<match.range.lowerBound]
            output += unchanged
            outputLength += unchanged.count

            let replacement = parsed?.expand(for: match, in: text) ?? ""
            output += replacement
            replacedRanges.append(outputLength..<(outputLength + replacement.count))
            outputLength += replacement.count

            copiedUpTo = match.range.upperBound
        }
        output += text[copiedUpTo...]
        return ReplacementResult(text: output, replacedRanges: replacedRanges)
    }
}

/// A line kept by the filter.
struct FilteredLine: Hashable, Sendable {
    /// The line's number in the original text, starting at 1.
    let number: Int
    let text: String
    /// The parts of the line that matched, as character offsets into ``text``.
    let matchRanges: [Range<Int>]
}

struct FilterResult: Equatable, Sendable {
    let lines: [FilteredLine]
    /// How many lines the original text has.
    let totalLineCount: Int

    /// The kept lines, ready to copy.
    var text: String {
        lines.map(\.text).joined(separator: "\n")
    }
}

enum LineFilter {
    /// Keeps the lines that contain at least one match, or with `inverted`, the lines that contain none.
    /// A match that spans several lines counts for each of them.
    static func filter(_ text: String, matches: [RegexMatch], inverted: Bool) -> FilterResult {
        var lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        // A final newline ends the last line rather than starting an empty one.
        if lines.count > 1, lines.last?.isEmpty == true {
            lines.removeLast()
        }

        var kept: [FilteredLine] = []
        // Matches never overlap and come in order, so each line only needs to look
        // from the first match that hasn't ended before it.
        var firstCandidate = 0

        for (offset, line) in lines.enumerated() {
            let lineStart = line.startIndex
            // The line's span including its newline, so a match on the newline counts for this line.
            let nextLineStart = offset + 1 < lines.count ? lines[offset + 1].startIndex : text.endIndex
            let isLastLine = offset + 1 == lines.count

            while firstCandidate < matches.count, endsBefore(matches[firstCandidate].range, lineStart) {
                firstCandidate += 1
            }

            var ranges: [Range<Int>] = []
            var hasMatch = false
            var candidate = firstCandidate
            while candidate < matches.count {
                let range = matches[candidate].range
                let startsInLine = range.lowerBound < nextLineStart || (isLastLine && range.lowerBound == text.endIndex)
                guard startsInLine else { break }
                hasMatch = true
                let clampedLower = max(range.lowerBound, lineStart)
                let clampedUpper = min(range.upperBound, line.endIndex)
                if clampedLower < clampedUpper {
                    let start = line.distance(from: lineStart, to: clampedLower)
                    ranges.append(start..<(start + line.distance(from: clampedLower, to: clampedUpper)))
                }
                candidate += 1
            }

            if hasMatch != inverted {
                kept.append(FilteredLine(number: offset + 1, text: String(line), matchRanges: inverted ? [] : ranges))
            }
        }
        return FilterResult(lines: kept, totalLineCount: lines.count)
    }

    /// Whether a match lies entirely before a line that starts at `lineStart`.
    private static func endsBefore(_ range: Range<String.Index>, _ lineStart: String.Index) -> Bool {
        range.isEmpty ? range.lowerBound < lineStart : range.upperBound <= lineStart
    }
}
