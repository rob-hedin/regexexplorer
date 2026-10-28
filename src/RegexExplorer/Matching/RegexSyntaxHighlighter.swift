// Copyright © 2026 Robert Hedin
// All Rights Reserved.

/// The parts of a pattern that the pattern field colours.
enum RegexSyntaxKind: Sendable, Equatable {
    /// An escape such as `\d`, `\.` or `\p{L}`, or a backreference such as `\1`.
    case escape
    /// A custom class such as `[a-z]`, a POSIX class, or the `.` wildcard.
    case characterClass
    /// The parentheses of a group and its prefix, such as `(?:`, `(?<name>` or `(?=`, with the
    /// capture group's number, or `nil` for a group that doesn't capture.
    case group(Int?)
    /// A quantifier such as `*`, `+?` or `{2,4}`.
    case quantifier
    /// `^`, `$`, or an anchor escape such as `\b` or `\A`.
    case anchor
    /// The `|` between alternatives.
    case alternation
    /// A `(?#…)` comment, or a `#` comment with extended syntax.
    case comment
}

/// One coloured run of a pattern, as character offsets.
struct RegexSyntaxToken: Sendable, Equatable {
    let kind: RegexSyntaxKind
    let range: Range<Int>
}

/// Splits a pattern into coloured runs. It never fails: anything it doesn't recognise
/// is left as a literal, so a half-typed pattern still colours sensibly.
enum RegexSyntaxHighlighter {
    private static let anchorEscapes: Set<Character> = ["b", "B", "A", "z", "Z", "G", "y", "Y"]
    /// Escapes that may take a `{…}` argument, such as `\p{L}` or `\x{1F600}`.
    private static let bracedEscapes: Set<Character> = ["p", "P", "x", "u", "N", "o", "g", "k"]

    static func tokens(in pattern: String, allowsExtendedSyntax: Bool = false) -> [RegexSyntaxToken] {
        let characters = Array(pattern)
        var tokens: [RegexSyntaxToken] = []
        var index = 0
        var classDepth = 0
        var captureCount = 0
        /// The number of each open group, or `nil` for one that doesn't capture.
        var openGroups: [Int?] = []

        func emit(_ kind: RegexSyntaxKind, _ start: Int, _ end: Int) {
            guard start < end else { return }
            if let last = tokens.last, last.kind == kind, last.range.upperBound == start {
                tokens[tokens.count - 1] = RegexSyntaxToken(kind: kind, range: last.range.lowerBound..<end)
            } else {
                tokens.append(RegexSyntaxToken(kind: kind, range: start..<end))
            }
        }

        func character(at offset: Int) -> Character? {
            offset < characters.count ? characters[offset] : nil
        }

        /// The offset just past `terminator`, or the end of the pattern if it never appears.
        func offsetPast(_ start: Int, terminator: Character) -> Int {
            guard start < characters.count, let found = characters[start...].firstIndex(of: terminator) else {
                return characters.count
            }
            return found + 1
        }

        /// The offset just past the escape that starts at `start`.
        func escapeEnd(from start: Int) -> Int {
            guard let marker = character(at: start + 1) else { return characters.count }
            if marker == "Q" {
                // \Q…\E quotes everything up to \E.
                var offset = start + 2
                while offset < characters.count {
                    if characters[offset] == "\\", character(at: offset + 1) == "E" { return offset + 2 }
                    offset += 1
                }
                return characters.count
            }
            if bracedEscapes.contains(marker), character(at: start + 2) == "{" {
                return offsetPast(start + 3, terminator: "}")
            }
            if marker == "k" || marker == "g", let open = character(at: start + 2), open == "<" || open == "'" {
                return offsetPast(start + 3, terminator: open == "<" ? ">" : "'")
            }
            if marker == "p" || marker == "P" { return min(start + 3, characters.count) }
            if marker == "x" {
                var offset = start + 2
                while offset < min(start + 4, characters.count), characters[offset].isHexDigit { offset += 1 }
                return offset
            }
            if marker.isASCII, marker.isNumber {
                var offset = start + 2
                while let next = character(at: offset), next.isASCII, next.isNumber { offset += 1 }
                return offset
            }
            return start + 2
        }

        /// The offset just past a `{n}`, `{n,}`, `{,m}` or `{n,m}` quantifier, or `nil` if it isn't one.
        func braceQuantifierEnd(from start: Int) -> Int? {
            var offset = start + 1
            var sawDigit = false
            var sawComma = false
            while let next = character(at: offset) {
                if next == "}" { return sawDigit ? offset + 1 : nil }
                if next.isASCII, next.isNumber {
                    sawDigit = true
                } else if next == ",", !sawComma {
                    sawComma = true
                } else {
                    return nil
                }
                offset += 1
            }
            return nil
        }

        /// Adds a lazy `?` or possessive `+` straight after a quantifier.
        func quantifierEnd(from offset: Int) -> Int {
            if let next = character(at: offset), next == "?" || next == "+" { return offset + 1 }
            return offset
        }

        /// The offset just past a group's opening, such as `(`, `(?:`, `(?<name>` or `(?i)`.
        func groupOpeningEnd(from start: Int) -> Int {
            guard character(at: start + 1) == "?" else {
                // (*atomic: and friends.
                if character(at: start + 1) == "*" {
                    let close = characters[(start + 1)...].firstIndex(where: { $0 == ":" || $0 == ")" })
                    return close.map { $0 + 1 } ?? characters.count
                }
                return start + 1
            }
            let markerOffset = start + 2
            switch character(at: markerOffset) {
            case "<":
                if let next = character(at: markerOffset + 1), next == "=" || next == "!" { return markerOffset + 2 }
                return offsetPast(markerOffset + 1, terminator: ">")
            case "'":
                return offsetPast(markerOffset + 1, terminator: "'")
            case "P":
                if character(at: markerOffset + 1) == "<" { return offsetPast(markerOffset + 2, terminator: ">") }
                return markerOffset + 1
            case "=", "!", ">", "|":
                return markerOffset + 1
            default:
                // Inline flags, such as (?i) or (?i-m:.
                var offset = markerOffset
                while let next = character(at: offset), next.isLetter || next == "-" || next == "^" { offset += 1 }
                if let next = character(at: offset), next == ":" || next == ")" { return offset + 1 }
                return offset
            }
        }

        /// The offset just past `[`, `[^`, and a `]` straight after them, which is a literal member.
        func classOpeningEnd(from start: Int) -> Int {
            var offset = start + 1
            if character(at: offset) == "^" { offset += 1 }
            if character(at: offset) == "]" { offset += 1 }
            return offset
        }

        /// Whether the group opening at `start` captures, numbered in the same order as Swift Regex.
        func capturesGroup(at start: Int) -> Bool {
            switch character(at: start + 1) {
            case "?":
                switch character(at: start + 2) {
                case "<":
                    if let next = character(at: start + 3), next == "=" || next == "!" { return false }
                    return true
                case "'":
                    return true
                case "P":
                    return character(at: start + 3) == "<"
                default:
                    return false
                }
            case "*":
                return false
            default:
                return true
            }
        }

        while index < characters.count {
            let current = characters[index]

            if current == "\\" {
                let end = escapeEnd(from: index)
                let marker = character(at: index + 1)
                let kind: RegexSyntaxKind = classDepth == 0 && marker.map(anchorEscapes.contains) == true
                    ? .anchor : .escape
                emit(kind, index, end)
                index = end
                continue
            }

            if classDepth > 0 {
                var end = index + 1
                if current == "[" {
                    if character(at: index + 1) == ":" {
                        // A POSIX class such as [:alpha:].
                        end = offsetPast(index + 2, terminator: "]")
                    } else {
                        classDepth += 1
                        end = classOpeningEnd(from: index)
                    }
                } else if current == "]" {
                    classDepth -= 1
                }
                emit(.characterClass, index, end)
                index = end
                continue
            }

            switch current {
            case "[":
                classDepth = 1
                let end = classOpeningEnd(from: index)
                emit(.characterClass, index, end)
                index = end
            case ".":
                emit(.characterClass, index, index + 1)
                index += 1
            case "(" where character(at: index + 1) == "?" && character(at: index + 2) == "#":
                let end = offsetPast(index + 3, terminator: ")")
                emit(.comment, index, end)
                index = end
            case "(":
                let end = groupOpeningEnd(from: index)
                if characters[end - 1] == ")" {
                    // Inline flags such as (?i) open no group.
                    emit(.group(nil), index, end)
                } else {
                    var number: Int?
                    if capturesGroup(at: index) {
                        captureCount += 1
                        number = captureCount
                    }
                    openGroups.append(number)
                    emit(.group(number), index, end)
                }
                index = end
            case ")":
                emit(.group(openGroups.popLast() ?? nil), index, index + 1)
                index += 1
            case "*", "+", "?":
                let end = quantifierEnd(from: index + 1)
                emit(.quantifier, index, end)
                index = end
            case "{":
                if let braceEnd = braceQuantifierEnd(from: index) {
                    let end = quantifierEnd(from: braceEnd)
                    emit(.quantifier, index, end)
                    index = end
                } else {
                    index += 1
                }
            case "^", "$":
                emit(.anchor, index, index + 1)
                index += 1
            case "|":
                emit(.alternation, index, index + 1)
                index += 1
            case "#" where allowsExtendedSyntax:
                var end = index
                while end < characters.count, !characters[end].isNewline { end += 1 }
                emit(.comment, index, end)
                index = end
            default:
                index += 1
            }
        }
        return tokens
    }
}
