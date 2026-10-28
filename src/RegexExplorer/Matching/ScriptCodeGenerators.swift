// Copyright © 2026 Robert Hedin

// Code generators for the scripting languages. Each one's output prints what the editor
// shows; see ``CodeGenerator``.

enum PythonCodeGenerator {
    static func code(for request: CodeRequest) -> String {
        let options = request.options
        var flags: [String] = []
        if options.ignoresCase { flags.append("re.IGNORECASE") }
        if options.anchorsMatchLineEndings { flags.append("re.MULTILINE") }
        if options.dotMatchesNewlines { flags.append("re.DOTALL") }
        if options.allowsExtendedSyntax { flags.append("re.VERBOSE") }

        var unsupported: [String] = []
        if request.features.contains(.unicodeProperty) { unsupported.append("\\p{…} properties") }
        if !request.features.isDisjoint(with: [.atomicGroup, .possessiveQuantifier]) {
            unsupported.append("atomic groups or possessive quantifiers before Python 3.11")
        }

        let pattern = request.pattern(PatternRewrite(namedGroups: .python))
        let flagArgument = flags.isEmpty ? "" : ", " + flags.joined(separator: " | ")
        var lines = request.notes(engine: "Python's re module", unsupported: unsupported, comment: "#")
        lines += [
            "import re",
            "",
            "pattern = re.compile(\(rawLiteral(pattern))\(flagArgument))",
            "text = \(StringLiteralStyle().literal(request.sampleText))",
            "",
        ]

        switch request.mode {
        case .match:
            lines.append("for match in pattern.finditer(text):")
            lines.append("    print(match.group(0))  # The whole match")
            for number in request.groups.indices.map({ $0 + 1 }) {
                lines.append("    print(match.group(\(number)) or \"\")  # \(request.label(forGroup: number))")
            }
        case .replace:
            let template = request.replacement.segments.map { segment in
                switch segment {
                case .literal(let literal): literal.replacing("\\", with: "\\\\")
                case .group(let number): "\\g<\(number)>"
                case .namedGroup(let name): "\\g<\(name)>"
                }
            }
            .joined()
            lines.append("result = pattern.sub(\(rawLiteral(template)), text)")
            lines.append("print(result)")
        case .filter:
            lines.append("lines = re.split(r\"\\r?\\n\", text)")
            lines.append("kept = [line for line in lines if \(request.invertsFilter ? "not " : "")pattern.search(line)]")
            lines.append("print(\"\\n\".join(kept))")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// A raw string literal where possible, so backslashes read as typed.
    static func rawLiteral(_ string: String) -> String {
        let trailingBackslashes = string.reversed().prefix { $0 == "\\" }.count
        if !string.contains(where: \.isNewline), trailingBackslashes.isMultiple(of: 2) {
            if !string.contains("\"") { return "r\"\(string)\"" }
            if !string.contains("'") { return "r'\(string)'" }
        }
        return StringLiteralStyle().literal(string)
    }
}

enum JavaScriptCodeGenerator {
    static func code(for request: CodeRequest) -> String {
        let options = request.options
        let features = request.features
        var flags = request.mode == .filter ? "" : "g"
        if options.ignoresCase { flags += "i" }
        if options.anchorsMatchLineEndings { flags += "m" }
        if options.dotMatchesNewlines { flags += "s" }
        if features.contains(.unicodeProperty) { flags += "u" }

        var unsupported: [String] = []
        if !features.isDisjoint(with: [.atomicGroup, .possessiveQuantifier]) {
            unsupported.append("atomic groups or possessive quantifiers")
        }
        if features.contains(.inlineFlags) { unsupported.append("inline flags such as (?i)") }
        if features.contains(.absoluteAnchor) { unsupported.append("\\A, \\z, \\Z or \\G") }

        let pattern = request.pattern(PatternRewrite(namedGroups: .angle, stripsExtendedSyntax: true))
        var lines = request.notes(engine: "JavaScript", unsupported: unsupported, comment: "//")
        lines.append("const regex = \(regexLiteral(pattern, flags: flags));")
        lines.append("const text = \(StringLiteralStyle().literal(request.sampleText));")
        lines.append("")

        switch request.mode {
        case .match:
            lines.append("for (const match of text.matchAll(regex)) {")
            lines.append("  console.log(match[0]); // The whole match")
            for number in request.groups.indices.map({ $0 + 1 }) {
                lines.append("  console.log(match[\(number)] ?? \"\"); // \(request.label(forGroup: number))")
            }
            lines.append("}")
        case .replace:
            lines.append("const result = text.replace(regex, \(StringLiteralStyle().literal(template(for: request))));")
            lines.append("console.log(result);")
        case .filter:
            lines.append("const lines = text.split(/\\r?\\n/);")
            lines.append("const kept = lines.filter((line) => \(request.invertsFilter ? "!" : "")regex.test(line));")
            lines.append("console.log(kept.join(\"\\n\"));")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// A /…/ literal, or `new RegExp(…)` for a pattern that a literal can't hold.
    static func regexLiteral(_ pattern: String, flags: String) -> String {
        guard !pattern.contains(where: \.isNewline) else {
            return "new RegExp(\(StringLiteralStyle().literal(pattern)), \"\(flags)\")"
        }
        return "/\(SlashEscaper.escape(pattern))/\(flags)"
    }

    /// A replacement string: `$&` for the match, `$1` or `$01` for a group, `$<name>`, and `$$`.
    static func template(for request: CodeRequest) -> String {
        let segments = request.replacement.segments
        return segments.indices.map { index in
            switch segments[index] {
            case .literal(let literal):
                return literal.replacing("$", with: "$$")
            case .group(0):
                return "$&"
            case .group(let number):
                // "$1" followed by a digit could read as "$12"; the two-digit form can't.
                return number < 10 && SegmentLookahead.nextStartsWithDigit(segments, after: index)
                    ? "$0\(number)" : "$\(number)"
            case .namedGroup(let name):
                return "$<\(name)>"
            }
        }
        .joined()
    }
}

enum PerlCodeGenerator {
    static func code(for request: CodeRequest) -> String {
        let options = request.options
        var flags = ""
        if options.ignoresCase { flags += "i" }
        if options.anchorsMatchLineEndings { flags += "m" }
        if options.dotMatchesNewlines { flags += "s" }
        if options.allowsExtendedSyntax { flags += "x" }

        let pattern = request.pattern.replacing("'", with: "\\'")
        let text = StringLiteralStyle(
            extraEscapes: ["$": "\\$", "@": "\\@"],
            control: { "\\x{" + StringLiteralStyle.hex($0, width: 2) + "}" }
        ).literal(request.sampleText)

        var lines = [
            "use strict;",
            "use warnings;",
            "use utf8;",
            "binmode STDOUT, \":encoding(UTF-8)\";",
            "",
            "my $regex = qr'\(pattern)'\(flags);",
            "my $text = \(text);",
            "",
        ]

        switch request.mode {
        case .match:
            lines.append("while ($text =~ /$regex/g) {")
            lines.append("    printf \"%s\\n\", $&;  # The whole match")
            for number in request.groups.indices.map({ $0 + 1 }) {
                let variable = request.groups[number - 1].map { "$+{\($0)}" } ?? "$\(number)"
                lines.append("    printf \"%s\\n\", \(variable) // \"\";  # \(request.label(forGroup: number))")
            }
            lines.append("}")
        case .replace:
            let replacement = request.replacement.segments.map { segment in
                switch segment {
                case .literal(let literal):
                    literal.map { "\\$@/".contains($0) ? "\\\($0)" : String($0) }.joined()
                        .replacing("\n", with: "\\n").replacing("\r", with: "\\r").replacing("\t", with: "\\t")
                case .group(0): "$&"
                case .group(let number): "${\(number)}"
                case .namedGroup(let name): "$+{\(name)}"
                }
            }
            .joined()
            if request.replacementUsesGroups {
                lines.append("no warnings 'uninitialized';  # A group that doesn't take part adds nothing.")
            }
            lines.append("my $result = $text =~ s/$regex/\(replacement)/gr;")
            lines.append("printf \"%s\\n\", $result;")
        case .filter:
            lines.append("my @lines = split /\\r?\\n/, $text, -1;")
            lines.append("my @kept = grep { \(request.invertsFilter ? "!" : "")/$regex/ } @lines;")
            lines.append("printf \"%s\\n\", join(\"\\n\", @kept);")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

enum PHPCodeGenerator {
    static func code(for request: CodeRequest) -> String {
        let options = request.options
        var flags = ""
        if options.ignoresCase { flags += "i" }
        if options.anchorsMatchLineEndings { flags += "m" }
        if options.dotMatchesNewlines { flags += "s" }
        if options.allowsExtendedSyntax { flags += "x" }
        flags += "u"

        let candidates: [Character] = options.allowsExtendedSyntax ? ["/", "~", "!", "%", "@"] : ["/", "~", "#", "!", "%", "@"]
        let pattern: String
        if let delimiter = candidates.first(where: { !request.pattern.contains($0) }) {
            pattern = "\(delimiter)\(request.pattern)\(delimiter)\(flags)"
        } else {
            pattern = "/\(SlashEscaper.escape(request.pattern))/\(flags)"
        }
        let text = StringLiteralStyle(
            extraEscapes: ["$": "\\$"],
            control: { "\\u{" + StringLiteralStyle.hex($0, width: 1) + "}" }
        ).literal(request.sampleText)

        var lines = [
            "<?php",
            "",
            "$pattern = \(singleQuoted(pattern));",
            "$text = \(text);",
            "",
        ]

        switch request.mode {
        case .match:
            lines.append("preg_match_all($pattern, $text, $matches, PREG_SET_ORDER);")
            lines.append("foreach ($matches as $match) {")
            lines.append("    echo $match[0], \"\\n\"; // The whole match")
            for number in request.groups.indices.map({ $0 + 1 }) {
                let key = request.groups[number - 1].map(singleQuoted) ?? String(number)
                lines.append("    echo $match[\(key)] ?? '', \"\\n\"; // \(request.label(forGroup: number))")
            }
            lines.append("}")
        case .replace:
            let parts = request.replacement.segments.map { segment in
                switch segment {
                case .literal(let literal): singleQuoted(literal)
                case .group(0): "$match[0]"
                case .group(let number): "($match[\(number)] ?? '')"
                case .namedGroup(let name): "($match[\(singleQuoted(name))] ?? '')"
                }
            }
            let body = parts.isEmpty ? "''" : parts.joined(separator: " . ")
            lines.append("$result = preg_replace_callback($pattern, fn ($match) => \(body), $text);")
            lines.append("echo $result, \"\\n\";")
        case .filter:
            lines.append("$lines = preg_split('/\\r?\\n/', $text);")
            lines.append("$kept = array_filter($lines, fn ($line) => preg_match($pattern, $line) \(request.invertsFilter ? "!==" : "===") 1);")
            lines.append("echo implode(\"\\n\", $kept), \"\\n\";")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// A single-quoted PHP string, where only `\\` and `\'` are escapes.
    static func singleQuoted(_ string: String) -> String {
        "'" + string.replacing("\\", with: "\\\\").replacing("'", with: "\\'") + "'"
    }
}

enum RubyCodeGenerator {
    static func code(for request: CodeRequest) -> String {
        let options = request.options
        // Ruby captures only named groups when a pattern has any, so give the others names too.
        let namesEveryGroup = request.hasNamedGroups && request.groups.contains(nil)
        let names = request.groups.enumerated().map { $1 ?? "group\($0 + 1)" }
        var rewrite = PatternRewrite(namedGroups: .angle)
        rewrite.namesUnnamedGroups = namesEveryGroup
        // Ruby's ^ and $ always match at line breaks.
        rewrite.anchorsMatchWholeText = !options.anchorsMatchLineEndings
        let pattern = request.pattern(rewrite)

        var unsupported: [String] = []
        if request.features.contains(.inlineFlags) { unsupported.append("inline flags the same way (its (?m) means \". matches newlines\")") }
        if namesEveryGroup, request.features.contains(.backreference) {
            unsupported.append("numbered backreferences in a pattern with named groups")
        }

        var lines = request.notes(engine: "Ruby", unsupported: unsupported, comment: "#")
        lines.append("regex = \(regexLiteral(pattern, options: options))")
        lines.append("text = \(doubleQuoted(request.sampleText))")
        lines.append("")

        func group(_ number: Int) -> String {
            if request.hasNamedGroups { return "match[:\(names[number - 1])]" }
            return "match[\(number)]"
        }

        switch request.mode {
        case .match:
            lines.append("text.scan(regex) do")
            lines.append("  match = Regexp.last_match")
            lines.append("  puts match[0] # The whole match")
            for number in request.groups.indices.map({ $0 + 1 }) {
                lines.append("  puts \(group(number)) # \(request.label(forGroup: number))")
            }
            lines.append("end")
        case .replace:
            let body = request.numberedReplacementSegments.map { segment in
                switch segment {
                case .literal(let literal): String(doubleQuoted(literal).dropFirst().dropLast())
                case .group(0): "#{match[0]}"
                case .group(let number): "#{\(group(number))}"
                case .namedGroup(let name): "#{match[:\(name)]}"
                }
            }
            .joined()
            if request.replacementUsesGroups {
                lines.append("result = text.gsub(regex) do")
                lines.append("  match = Regexp.last_match")
                lines.append("  \"\(body)\"")
                lines.append("end")
            } else {
                lines.append("result = text.gsub(regex) { \"\(body)\" }")
            }
            lines.append("puts result")
        case .filter:
            lines.append("lines = text.split(/\\r?\\n/, -1)")
            lines.append("kept = lines.\(request.invertsFilter ? "reject" : "select") { |line| line.match?(regex) }")
            lines.append("puts kept.join(\"\\n\")")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// A /…/ literal, or `Regexp.new` for a pattern that a literal would change.
    static func regexLiteral(_ pattern: String, options: RegexOptions) -> String {
        if !pattern.contains("#"), !pattern.contains(where: \.isNewline) {
            var flags = ""
            if options.ignoresCase { flags += "i" }
            if options.dotMatchesNewlines { flags += "m" }
            if options.allowsExtendedSyntax { flags += "x" }
            return "/\(SlashEscaper.escape(pattern))/\(flags)"
        }
        var flags: [String] = []
        if options.ignoresCase { flags.append("Regexp::IGNORECASE") }
        if options.dotMatchesNewlines { flags.append("Regexp::MULTILINE") }
        if options.allowsExtendedSyntax { flags.append("Regexp::EXTENDED") }
        let quoted = "'" + pattern.replacing("\\", with: "\\\\").replacing("'", with: "\\'") + "'"
        return "Regexp.new(\(quoted)\(flags.isEmpty ? "" : ", " + flags.joined(separator: " | ")))"
    }

    /// A double-quoted string, with `#` escaped so nothing interpolates.
    static func doubleQuoted(_ string: String) -> String {
        StringLiteralStyle(
            extraEscapes: ["#": "\\#"],
            control: { "\\u{" + StringLiteralStyle.hex($0, width: 1) + "}" }
        ).literal(string)
    }
}

enum RCodeGenerator {
    static func code(for request: CodeRequest) -> String {
        let options = request.options
        var flags = ""
        if options.ignoresCase { flags += "i" }
        if options.anchorsMatchLineEndings { flags += "m" }
        if options.dotMatchesNewlines { flags += "s" }
        if options.allowsExtendedSyntax { flags += "x" }

        var unsupported: [String] = []
        var segments = request.numberedReplacementSegments
        var body = request.pattern
        // gsub has no reference to the whole match, so the pattern goes in a group of its own
        // and every other group moves up by one.
        if request.mode == .replace, segments.contains(.group(0)) {
            if request.features.contains(.backreference) {
                unsupported.append("replacing with the whole match in a pattern with backreferences")
            }
            body = "(" + body + (options.allowsExtendedSyntax ? "\n)" : ")")
            segments = segments.map { if case .group(let number) = $0 { .group(number + 1) } else { $0 } }
        }
        if request.mode == .replace, segments.contains(where: { if case .group(let number) = $0 { number > 9 } else { false } }) {
            unsupported.append("replacing with groups after \\9")
        }
        let pattern = (flags.isEmpty ? "" : "(?\(flags))") + body

        var lines = request.notes(engine: "R", unsupported: unsupported, comment: "#")
        lines.append("pattern <- \(rawLiteral(pattern))")
        lines.append("text <- \(StringLiteralStyle().literal(request.sampleText))")
        lines.append("")

        switch request.mode {
        case .match:
            lines.append("found <- regmatches(text, gregexec(pattern, text, perl = TRUE))[[1]]")
            lines.append("if (is.matrix(found)) {")
            lines.append("  for (column in seq_len(ncol(found))) {")
            lines.append("    cat(found[1, column], \"\\n\", sep = \"\") # The whole match")
            for number in request.groups.indices.map({ $0 + 1 }) {
                lines.append("    cat(found[\(number + 1), column], \"\\n\", sep = \"\") # \(request.label(forGroup: number))")
            }
            lines.append("  }")
            lines.append("}")
        case .replace:
            let template = segments.map { segment in
                switch segment {
                case .literal(let literal): literal.replacing("\\", with: "\\\\")
                case .group(let number): "\\\(number)"
                case .namedGroup(let name): "\\k<\(name)>"
                }
            }
            .joined()
            lines.append("result <- gsub(pattern, \(StringLiteralStyle().literal(template)), text, perl = TRUE)")
            lines.append("cat(result, \"\\n\", sep = \"\")")
        case .filter:
            lines.append("lines <- strsplit(text, \"\\r?\\n\")[[1]]")
            lines.append("kept <- lines[\(request.invertsFilter ? "!" : "")grepl(pattern, lines, perl = TRUE)]")
            lines.append("cat(paste(kept, collapse = \"\\n\"), \"\\n\", sep = \"\")")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// An R 4 raw string, such as r"(…)", with dashes if the pattern holds `)"`.
    static func rawLiteral(_ string: String) -> String {
        var dashes = ""
        while string.contains(")\(dashes)\"") {
            dashes += "-"
        }
        return "r\"\(dashes)(\(string))\(dashes)\""
    }
}

/// Escapes each unescaped `/` in a pattern, for languages that write regexes between slashes.
enum SlashEscaper {
    static func escape(_ pattern: String) -> String {
        var result = ""
        var escaping = false
        for character in pattern {
            if escaping {
                result.append(character)
                escaping = false
            } else if character == "\\" {
                result.append(character)
                escaping = true
            } else if character == "/" {
                result += "\\/"
            } else {
                result.append(character)
            }
        }
        return result
    }
}

enum SegmentLookahead {
    /// Whether the segment after `index` is text that starts with a digit.
    static func nextStartsWithDigit(_ segments: [ReplacementTemplate.Segment], after index: Int) -> Bool {
        guard index + 1 < segments.count, case .literal(let next) = segments[index + 1] else { return false }
        return next.first.map { $0.isASCII && $0.isNumber } ?? false
    }
}
