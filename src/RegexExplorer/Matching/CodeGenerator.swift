// Copyright © 2026 Robert Hedin
// All Rights Reserved.

/// Writes code in any ``CodeLanguage`` that does what the editor shows for a saved regex.
///
/// Every language's code prints the same thing: in Match mode each match and then each of
/// its groups on its own line (a group that didn't take part prints as an empty line), in
/// Replace mode the replaced text, and in Filter mode the kept lines.
enum CodeGenerator {
    static func code(for regex: SavedRegex, language: CodeLanguage) -> String {
        let request = CodeRequest(regex: regex)
        switch language {
        case .swift6: return SwiftCodeGenerator.code(for: regex, languageMode: .swift6)
        case .swift5: return SwiftCodeGenerator.code(for: regex, languageMode: .swift5)
        case .csharp: return CSharpCodeGenerator.code(for: request)
        case .cpp: return CppCodeGenerator.code(for: request)
        case .go: return GoCodeGenerator.code(for: request)
        case .java: return JavaCodeGenerator.code(for: request)
        case .javascript: return JavaScriptCodeGenerator.code(for: request)
        case .kotlin: return KotlinCodeGenerator.code(for: request)
        case .perl: return PerlCodeGenerator.code(for: request)
        case .php: return PHPCodeGenerator.code(for: request)
        case .python: return PythonCodeGenerator.code(for: request)
        case .r: return RCodeGenerator.code(for: request)
        case .ruby: return RubyCodeGenerator.code(for: request)
        case .rust: return RustCodeGenerator.code(for: request)
        }
    }
}

/// What every generator needs to know about a saved regex.
struct CodeRequest {
    let pattern: String
    let options: RegexOptions
    let mode: ExplorerMode
    let invertsFilter: Bool
    /// One entry per capture group, in order: its name, or `nil`.
    let groups: [String?]
    let replacement: ReplacementTemplate
    let features: PatternFeatures
    let sampleText: String

    init(regex: SavedRegex) {
        let extended = regex.options.allowsExtendedSyntax
        pattern = regex.pattern
        options = regex.options
        mode = regex.mode
        invertsFilter = regex.invertsFilter
        groups = CaptureGroupScanner.groups(in: regex.pattern, allowsExtendedSyntax: extended)
        replacement = ReplacementTemplate(
            regex.replacement,
            groupCount: groups.count,
            groupNames: Set(groups.compactMap { $0 })
        )
        features = PatternFeatures(pattern: regex.pattern, allowsExtendedSyntax: extended)
        sampleText = regex.sampleText.isEmpty ? "Your text here" : regex.sampleText
    }

    var hasNamedGroups: Bool { groups.contains { $0 != nil } }

    /// The number of the group called `name`, starting at 1.
    func number(ofGroup name: String) -> Int? {
        groups.firstIndex(of: name).map { $0 + 1 }
    }

    /// A comment for group `number`, such as "Group 2" or "Group 2 (year)".
    func label(forGroup number: Int) -> String {
        groups[number - 1].map { "Group \(number) (\($0))" } ?? "Group \(number)"
    }

    /// The replacement with every named group turned into its number.
    var numberedReplacementSegments: [ReplacementTemplate.Segment] {
        replacement.segments.map { segment in
            if case .namedGroup(let name) = segment, let number = number(ofGroup: name) { .group(number) } else { segment }
        }
    }

    /// Whether the replacement uses any group, as opposed to being plain text.
    var replacementUsesGroups: Bool {
        replacement.segments.contains { if case .literal = $0 { false } else { true } }
    }

    /// The pattern rewritten for another engine.
    func pattern(_ rewrite: PatternRewrite) -> String {
        rewrite.apply(to: pattern, groups: groups, allowsExtendedSyntax: options.allowsExtendedSyntax)
    }

    /// Comment lines warning about the parts of the pattern or options an engine lacks.
    func notes(engine: String, unsupported: [String], comment: String) -> [String] {
        guard !unsupported.isEmpty else { return [] }
        let list = EnglishList.join(unsupported)
        return [
            "\(comment) Note: \(engine) doesn't support \(list), so this pattern",
            "\(comment) needs changing before it works the same way here.",
            "",
        ]
    }
}

/// Regex features that some engines lack.
struct PatternFeatures: OptionSet, Sendable {
    let rawValue: Int

    static let lookahead = PatternFeatures(rawValue: 1 << 0)
    static let lookbehind = PatternFeatures(rawValue: 1 << 1)
    static let backreference = PatternFeatures(rawValue: 1 << 2)
    static let atomicGroup = PatternFeatures(rawValue: 1 << 3)
    static let possessiveQuantifier = PatternFeatures(rawValue: 1 << 4)
    static let unicodeProperty = PatternFeatures(rawValue: 1 << 5)
    static let inlineFlags = PatternFeatures(rawValue: 1 << 6)
    /// `\A`, `\z`, `\Z` or `\G`.
    static let absoluteAnchor = PatternFeatures(rawValue: 1 << 7)
    /// `\Z` in particular, which some engines that have `\A` and `\z` lack.
    static let endBeforeFinalNewline = PatternFeatures(rawValue: 1 << 8)

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    init(pattern: String, allowsExtendedSyntax: Bool) {
        let characters = Array(pattern)
        var features: PatternFeatures = []
        for token in RegexSyntaxHighlighter.tokens(in: pattern, allowsExtendedSyntax: allowsExtendedSyntax) {
            let text = String(characters[token.range])
            switch token.kind {
            case .group:
                if text.contains("(?=") || text.contains("(?!") { features.insert(.lookahead) }
                if text.contains("(?<=") || text.contains("(?<!") { features.insert(.lookbehind) }
                if text.contains("(?>") || text.contains("(*atomic") { features.insert(.atomicGroup) }
                if text.contains("(?P=") { features.insert(.backreference) }
                if Self.hasInlineFlags(text) { features.insert(.inlineFlags) }
            case .quantifier:
                if text.count > 1, text.last == "+" { features.insert(.possessiveQuantifier) }
            case .escape:
                // Merged runs can hold several escapes, so look at each backslash.
                var index = text.startIndex
                while let slash = text[index...].firstIndex(of: "\\") {
                    let next = text.index(after: slash)
                    guard next < text.endIndex else { break }
                    let marker = text[next]
                    if marker == "p" || marker == "P" { features.insert(.unicodeProperty) }
                    if marker == "k" || marker == "g" || ("1"..."9").contains(marker) { features.insert(.backreference) }
                    index = text.index(after: next)
                }
            case .anchor:
                for marker in ["\\A", "\\z", "\\Z", "\\G"] where text.contains(marker) {
                    features.insert(.absoluteAnchor)
                    if marker == "\\Z" { features.insert(.endBeforeFinalNewline) }
                }
            default:
                break
            }
        }
        self = features
    }

    /// Whether a group run such as `(?i)` or `)(?i-m:` sets flags.
    private static func hasInlineFlags(_ text: String) -> Bool {
        var remainder = Substring(text)
        while let open = remainder.firstRange(of: "(?") {
            let after = remainder[open.upperBound...]
            let flags = after.prefix { $0.isLetter || $0 == "-" || $0 == "^" }
            if !flags.isEmpty, let end = after.dropFirst(flags.count).first, end == ")" || end == ":",
               flags.allSatisfy({ "imsxnwUuXJ-^".contains($0) }) {
                return true
            }
            remainder = after
        }
        return false
    }
}

/// Changes to a pattern so another engine reads it the same way.
struct PatternRewrite {
    enum NamedGroupStyle {
        /// Leave named groups as typed.
        case keep
        /// `(?<name>…)` and `\k<name>`.
        case angle
        /// `(?P<name>…)` and `(?P=name)`.
        case python
        /// Plain groups and numbered backreferences, for engines without names.
        case unnamed
    }

    var namedGroups: NamedGroupStyle = .keep
    /// Removes the whitespace and `#` comments that "Ignore whitespace" skips.
    var stripsExtendedSyntax = false
    /// Writes `.` as `[\s\S]`, for engines with no "dot matches newlines" flag.
    var dotMatchesNewlines = false
    /// Writes `^` as `\A` and `$` as `\Z`, for engines whose `^` and `$` always match at lines.
    var anchorsMatchWholeText = false
    /// Names each unnamed group "group1", "group2" and so on, by its number.
    var namesUnnamedGroups = false

    func apply(to pattern: String, groups: [String?], allowsExtendedSyntax: Bool) -> String {
        let characters = Array(pattern)
        var output = ""
        var index = 0
        var classDepth = 0
        var captureCount = 0

        func character(at offset: Int) -> Character? {
            offset < characters.count ? characters[offset] : nil
        }

        /// The name that starts at `start` and ends before `terminator`, and the offset past it.
        func name(from start: Int, terminator: Character) -> (name: String, end: Int)? {
            guard start < characters.count, let end = characters[start...].firstIndex(of: terminator) else { return nil }
            return (String(characters[start..<end]), end + 1)
        }

        func backreference(to name: String) -> String {
            switch namedGroups {
            case .keep, .angle: "\\k<\(name)>"
            case .python: "(?P=\(name))"
            case .unnamed: groups.firstIndex(of: name).map { "\\\($0 + 1)" } ?? "\\k<\(name)>"
            }
        }

        func groupOpening(named name: String) -> String {
            switch namedGroups {
            case .keep, .angle: "(?<\(name)>"
            case .python: "(?P<\(name)>"
            case .unnamed: "("
            }
        }

        while index < characters.count {
            let current = characters[index]

            if current == "\\" {
                let marker = character(at: index + 1)
                if namedGroups != .keep, marker == "k", let open = character(at: index + 2),
                   let terminator: Character = ["<": ">", "'": "'", "{": "}"][open],
                   let found = name(from: index + 3, terminator: terminator) {
                    output += backreference(to: found.name)
                    index = found.end
                    continue
                }
                output.append(current)
                if let marker { output.append(marker) }
                index += 2
                continue
            }

            if classDepth > 0 {
                if current == "[", character(at: index + 1) == ":",
                   let found = name(from: index + 2, terminator: "]") {
                    output += String(characters[index..<found.end])
                    index = found.end
                    continue
                }
                if current == "[" { classDepth += 1 }
                if current == "]" { classDepth -= 1 }
                output.append(current)
                index += 1
                continue
            }

            if current == "[" {
                classDepth = 1
                output.append(current)
                index += 1
                // A "]" straight after "[" or "[^" is a literal member.
                if character(at: index) == "^" { output.append("^"); index += 1 }
                if character(at: index) == "]" { output.append("]"); index += 1 }
                continue
            }

            if allowsExtendedSyntax, stripsExtendedSyntax {
                if current == "#" {
                    while index < characters.count, !characters[index].isNewline { index += 1 }
                    continue
                }
                if current.isWhitespace {
                    index += 1
                    continue
                }
            }

            if current == "(", let next = character(at: index + 1) {
                if next != "?", next != "*" {
                    captureCount += 1
                    if namesUnnamedGroups {
                        output += "(?<group\(captureCount)>"
                        index += 1
                        continue
                    }
                } else if next == "?" {
                    let marker = character(at: index + 2)
                    var named: (name: String, end: Int)?
                    if marker == "<", let after = character(at: index + 3), after != "=", after != "!" {
                        named = name(from: index + 3, terminator: ">")
                    } else if marker == "'" {
                        named = name(from: index + 3, terminator: "'")
                    } else if marker == "P", character(at: index + 3) == "<" {
                        named = name(from: index + 4, terminator: ">")
                    } else if namedGroups != .keep, marker == "P", character(at: index + 3) == "=",
                              let found = name(from: index + 4, terminator: ")") {
                        output += backreference(to: found.name)
                        index = found.end
                        continue
                    }
                    if let named {
                        captureCount += 1
                        output += namedGroups == .keep ? String(characters[index..<named.end]) : groupOpening(named: named.name)
                        index = named.end
                        continue
                    }
                }
            }

            if current == ".", dotMatchesNewlines {
                output += "[\\s\\S]"
            } else if current == "^", anchorsMatchWholeText {
                output += "\\A"
            } else if current == "$", anchorsMatchWholeText {
                output += "\\Z"
            } else {
                output.append(current)
            }
            index += 1
        }
        return output
    }
}

/// Joins words as "a", "a and b", or "a, b and c".
enum EnglishList {
    static func join(_ items: [String]) -> String {
        switch items.count {
        case 0: ""
        case 1: items[0]
        default: items.dropLast().joined(separator: ", ") + " and " + items.last!
        }
    }
}

/// Builds quoted string literals for the C family of languages.
struct StringLiteralStyle {
    var quote: Character = "\""
    /// Characters beyond the backslash and quote that need escaping, and how.
    var extraEscapes: [Character: String] = [:]
    /// How a control character other than \n, \r and \t is written.
    var control: (UInt32) -> String = { "\\u" + StringLiteralStyle.hex($0, width: 4) }

    func literal(_ string: String) -> String {
        var result = String(quote)
        for character in string {
            if character == "\r\n" {
                result += "\\r\\n"
                continue
            }
            if let escape = extraEscapes[character] {
                result += escape
                continue
            }
            switch character {
            case "\\": result += "\\\\"
            case quote: result += "\\" + String(quote)
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            default:
                if let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1,
                   scalar.properties.generalCategory == .control {
                    result += control(scalar.value)
                } else {
                    result.append(character)
                }
            }
        }
        result.append(quote)
        return result
    }

    static func hex(_ value: UInt32, width: Int) -> String {
        let digits = String(value, radix: 16, uppercase: true)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }
}
