// Copyright © 2026 Robert Hedin

import Foundation

/// Finds a pattern's capture groups from its source text, without matching anything.
enum CaptureGroupScanner {
    /// One entry per capture group, in order: the group's name, or `nil` for an unnamed group.
    static func groups(in pattern: String, allowsExtendedSyntax: Bool = false) -> [String?] {
        let characters = Array(pattern)
        var groups: [String?] = []
        var index = 0
        var inClass = false

        func name(from start: Int, upTo terminator: Character) -> String? {
            guard let end = characters[start...].firstIndex(of: terminator) else { return nil }
            return String(characters[start..<end])
        }

        while index < characters.count {
            let character = characters[index]
            if character == "\\" {
                index += 2
                continue
            }
            if inClass {
                if character == "]" { inClass = false }
                index += 1
                continue
            }
            switch character {
            case "[":
                inClass = true
                // A "]" straight after "[" or "[^" is a literal member, not the end of the class.
                if index + 1 < characters.count, characters[index + 1] == "^" { index += 1 }
                if index + 1 < characters.count, characters[index + 1] == "]" { index += 1 }
            case "#" where allowsExtendedSyntax:
                while index < characters.count, !characters[index].isNewline { index += 1 }
            case "(":
                let rest = characters[(index + 1)...]
                if rest.first == "?" {
                    let afterQuestion = index + 2
                    let marker = afterQuestion < characters.count ? characters[afterQuestion] : nil
                    let nameStart = afterQuestion + 1
                    switch marker {
                    case "<" where nameStart < characters.count && characters[nameStart] != "=" && characters[nameStart] != "!":
                        groups.append(name(from: nameStart, upTo: ">"))
                    case "'":
                        groups.append(name(from: nameStart, upTo: "'"))
                    case "P" where nameStart < characters.count && characters[nameStart] == "<":
                        groups.append(name(from: nameStart + 1, upTo: ">"))
                    default:
                        break // Non-capturing group, lookaround, or inline flags.
                    }
                } else if rest.first != "*" {
                    groups.append(nil)
                }
            default:
                break
            }
            index += 1
        }
        return groups
    }
}

/// The Swift language mode the generated code is written for.
enum SwiftLanguageMode: String, CaseIterable, Identifiable, Sendable {
    /// Uses bare /…/ regex literals where the pattern allows.
    case swift6
    /// Uses #/…/# regex literals, which also compile in Swift 6.
    case swift5

    var id: Self { self }

    var title: String {
        switch self {
        case .swift6: "Swift 6"
        case .swift5: "Swift 5"
        }
    }
}

/// Writes Swift code that does what the editor shows for a saved regex.
enum SwiftCodeGenerator {
    static func code(for regex: SavedRegex, languageMode: SwiftLanguageMode = .swift6) -> String {
        let source = regex.options.allowsExtendedSyntax ? "(?x)" + regex.pattern : regex.pattern
        let groups = CaptureGroupScanner.groups(in: regex.pattern, allowsExtendedSyntax: regex.options.allowsExtendedSyntax)
        let literal = regexLiteral(for: source, languageMode: languageMode)

        var lines: [String] = []
        if let literal {
            lines.append("let regex = \(literal)")
        } else {
            lines.append("// A regex literal can't hold this pattern, so it's compiled when the code runs.")
            lines.append("let regex = try Regex(\(stringLiteral(source)))")
        }
        lines += optionModifiers(for: regex.options).map { "    \($0)" }
        lines.append("")
        lines.append("let text = \(stringLiteral(regex.sampleText.isEmpty ? "Your text here" : regex.sampleText))")
        lines.append("")

        switch regex.mode {
        case .match:
            lines += matchCode(groups: groups, isLiteral: literal != nil)
        case .replace:
            lines += replaceCode(template: regex.replacement, groups: groups)
        case .filter:
            lines += filterCode(inverted: regex.invertsFilter)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// The pattern as a regex literal, or `nil` if a literal can't hold it.
    static func regexLiteral(for source: String, languageMode: SwiftLanguageMode = .swift6) -> String? {
        // Literals are a single line here, and Swift checks them when the code compiles.
        guard !source.isEmpty, !source.contains(where: \.isNewline) else { return nil }

        // Bare /…/ literals only compile in the Swift 6 language mode (or with
        // -enable-bare-slash-regex). Even then they can't contain "/", can't start or
        // end with whitespace, and can't start with "*" (which would read as a comment).
        let needsDelimiters = languageMode == .swift5
            || source.contains("/")
            || source.first!.isWhitespace || source.last!.isWhitespace
            || source.hasPrefix("*")
        guard needsDelimiters else { return "/\(source)/" }

        var hashes = "#"
        while source.contains("/" + hashes) {
            hashes += "#"
        }
        return "\(hashes)/\(source)/\(hashes)"
    }

    /// A Swift string literal for `string`, with special characters escaped.
    static func stringLiteral(_ string: String) -> String {
        "\"" + escaped(string) + "\""
    }

    private static func escaped(_ string: String) -> String {
        var result = ""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\\": result += "\\\\"
            case "\"": result += "\\\""
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            case _ where scalar.properties.generalCategory == .control:
                result += "\\u{\(String(scalar.value, radix: 16))}"
            default:
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    private static func optionModifiers(for options: RegexOptions) -> [String] {
        var modifiers: [String] = []
        if options.ignoresCase { modifiers.append(".ignoresCase()") }
        if options.anchorsMatchLineEndings { modifiers.append(".anchorsMatchLineEndings()") }
        if options.dotMatchesNewlines { modifiers.append(".dotMatchesNewlines()") }
        if options.usesSimpleWordBoundaries { modifiers.append(".wordBoundaryKind(.simple)") }
        return modifiers
    }

    private static func matchCode(groups: [String?], isLiteral: Bool) -> [String] {
        var lines = ["for match in text.matches(of: regex) {"]
        if isLiteral {
            // A literal's output is typed: the whole match, then each group by name or position.
            if groups.isEmpty {
                lines.append("    print(match.output)")
            } else {
                lines.append("    print(match.output.0) // The whole match")
                // A group is Substring? when it may not take part, such as (b)?, and Substring
                // otherwise; "as Substring?" reads either without a warning.
                for (offset, name) in groups.enumerated() {
                    let element = "match.output.\(name ?? String(offset + 1))"
                    lines.append("    print(\(element) as Substring? ?? \"\") // Group \(offset + 1)")
                }
            }
        } else {
            lines.append("    print(match.output[0].substring ?? \"\") // The whole match")
            for (offset, name) in groups.enumerated() {
                let element = name.map { "match.output[\(stringLiteral($0))]?" } ?? "match.output[\(offset + 1)]"
                lines.append("    print(\(element).substring ?? \"\") // Group \(offset + 1)")
            }
        }
        lines.append("}")
        return lines
    }

    private static func replaceCode(template: String, groups: [String?]) -> [String] {
        let parsed = ReplacementTemplate(template, groupCount: groups.count, groupNames: Set(groups.compactMap { $0 }))
        let usesGroups = parsed.segments.contains { if case .literal = $0 { false } else { true } }
        guard usesGroups else {
            return [
                "let result = text.replacing(regex, with: \(stringLiteral(template)))",
                "print(result)",
            ]
        }

        let interpolated = parsed.segments.map { segment in
            switch segment {
            case .literal(let literal): escaped(literal)
            case .group(let number): "\\(groups[\(number)].substring ?? \"\")"
            case .namedGroup(let name): "\\(groups[\(stringLiteral(name))]?.substring ?? \"\")"
            }
        }
        .joined()

        return [
            "let result = text.replacing(regex) { match in",
            "    let groups = AnyRegexOutput(match)",
            "    return \"\(interpolated)\"",
            "}",
            "print(result)",
        ]
    }

    private static func filterCode(inverted: Bool) -> [String] {
        [
            "// Each line is matched on its own.",
            "let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \\.isNewline)",
            "let kept = lines.filter { \(inverted ? "!" : "")$0.contains(regex) }",
            "print(kept.joined(separator: \"\\n\"))",
        ]
    }
}
