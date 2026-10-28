// Code generators for the compiled languages. Each one's output prints what the editor
// shows; see ``CodeGenerator``.

/// Flags written into the pattern itself, such as `(?im)`, for engines that read them.
private func inlineFlags(_ options: RegexOptions, extended: Bool = true) -> String {
    var flags = ""
    if options.ignoresCase { flags += "i" }
    if options.anchorsMatchLineEndings { flags += "m" }
    if options.dotMatchesNewlines { flags += "s" }
    if extended, options.allowsExtendedSyntax { flags += "x" }
    return flags.isEmpty ? "" : "(?\(flags))"
}

enum GoCodeGenerator {
    static func code(for request: CodeRequest) -> String {
        let features = request.features
        var unsupported: [String] = []
        if !features.isDisjoint(with: [.lookahead, .lookbehind]) { unsupported.append("lookarounds") }
        if features.contains(.backreference) { unsupported.append("backreferences") }
        if !features.isDisjoint(with: [.atomicGroup, .possessiveQuantifier]) {
            unsupported.append("atomic groups or possessive quantifiers")
        }
        if features.contains(.endBeforeFinalNewline) { unsupported.append("\\Z") }

        // RE2 has no "ignore whitespace" flag, so the whitespace and comments are removed instead.
        let pattern = inlineFlags(request.options, extended: false)
            + request.pattern(PatternRewrite(namedGroups: .python, stripsExtendedSyntax: true))
        var imports = ["\"fmt\"", "\"regexp\""]
        if request.mode == .filter { imports.append("\"strings\"") }

        var lines = request.notes(engine: "Go's regexp package", unsupported: unsupported, comment: "//")
        lines += ["package main", "", "import ("]
        lines += imports.map { "\t\($0)" }
        lines += [
            ")",
            "",
            "func main() {",
            "\tre := regexp.MustCompile(\(literal(pattern)))",
            "\ttext := \(StringLiteralStyle().literal(request.sampleText))",
            "",
        ]

        switch request.mode {
        case .match:
            lines.append("\tfor _, match := range re.FindAllStringSubmatch(text, -1) {")
            lines.append("\t\tfmt.Println(match[0]) // The whole match")
            for number in request.groups.indices.map({ $0 + 1 }) {
                lines.append("\t\tfmt.Println(match[\(number)]) // \(request.label(forGroup: number))")
            }
            lines.append("\t}")
        case .replace:
            lines.append("\tresult := re.ReplaceAllString(text, \(StringLiteralStyle().literal(DollarBraceTemplate.make(request))))")
            lines.append("\tfmt.Println(result)")
        case .filter:
            lines.append("\tvar kept []string")
            lines.append("\tfor _, line := range regexp.MustCompile(`\\r?\\n`).Split(text, -1) {")
            lines.append("\t\tif \(request.invertsFilter ? "!" : "")re.MatchString(line) {")
            lines.append("\t\t\tkept = append(kept, line)")
            lines.append("\t\t}")
            lines.append("\t}")
            lines.append("\tfmt.Println(strings.Join(kept, \"\\n\"))")
        }
        lines.append("}")
        return lines.joined(separator: "\n") + "\n"
    }

    /// A raw `…` string where possible.
    static func literal(_ string: String) -> String {
        string.contains("`") ? StringLiteralStyle().literal(string) : "`\(string)`"
    }
}

enum RustCodeGenerator {
    static func code(for request: CodeRequest) -> String {
        let features = request.features
        var unsupported: [String] = []
        if !features.isDisjoint(with: [.lookahead, .lookbehind]) { unsupported.append("lookarounds") }
        if features.contains(.backreference) { unsupported.append("backreferences") }
        if !features.isDisjoint(with: [.atomicGroup, .possessiveQuantifier]) {
            unsupported.append("atomic groups or possessive quantifiers")
        }
        if features.contains(.endBeforeFinalNewline) { unsupported.append("\\Z") }

        let pattern = inlineFlags(request.options) + request.pattern(PatternRewrite(namedGroups: .python))
        let text = StringLiteralStyle(control: { "\\u{" + StringLiteralStyle.hex($0, width: 1) + "}" })
            .literal(request.sampleText)

        var lines = request.notes(engine: "Rust's regex crate", unsupported: unsupported, comment: "//")
        lines += [
            "// Cargo.toml: [dependencies] regex = \"1\"",
            "use regex::Regex;",
            "",
            "fn main() {",
            "    let regex = Regex::new(\(rawLiteral(pattern))).unwrap();",
            "    let text = \(text);",
            "",
        ]

        switch request.mode {
        case .match:
            lines.append("    for captures in regex.captures_iter(text) {")
            lines.append("        println!(\"{}\", &captures[0]); // The whole match")
            for number in request.groups.indices.map({ $0 + 1 }) {
                lines.append("        println!(\"{}\", captures.get(\(number)).map_or(\"\", |group| group.as_str())); // \(request.label(forGroup: number))")
            }
            lines.append("    }")
        case .replace:
            lines.append("    let result = regex.replace_all(text, \(rawLiteral(DollarBraceTemplate.make(request))));")
            lines.append("    println!(\"{result}\");")
        case .filter:
            lines.append("    let kept: Vec<&str> = text")
            lines.append("        .split('\\n')")
            lines.append("        .map(|line| line.strip_suffix('\\r').unwrap_or(line))")
            lines.append("        .filter(|line| \(request.invertsFilter ? "!" : "")regex.is_match(line))")
            lines.append("        .collect();")
            lines.append("    println!(\"{}\", kept.join(\"\\n\"));")
        }
        lines.append("}")
        return lines.joined(separator: "\n") + "\n"
    }

    /// A raw r"…" string, with as many #s as it needs.
    static func rawLiteral(_ string: String) -> String {
        var hashes = ""
        while string.contains("\"\(hashes)") {
            hashes += "#"
        }
        return "r\(hashes)\"\(string)\"\(hashes)"
    }
}

enum JavaCodeGenerator {
    static func code(for request: CodeRequest) -> String {
        let options = request.options
        var flags: [String] = []
        if options.ignoresCase { flags += ["Pattern.CASE_INSENSITIVE", "Pattern.UNICODE_CASE"] }
        if options.anchorsMatchLineEndings { flags.append("Pattern.MULTILINE") }
        if options.dotMatchesNewlines { flags.append("Pattern.DOTALL") }
        if options.allowsExtendedSyntax { flags.append("Pattern.COMMENTS") }

        let pattern = request.pattern(PatternRewrite(namedGroups: .angle))
        let flagArgument = flags.isEmpty ? "" : ", " + flags.joined(separator: " | ")
        var imports = ["java.util.regex.Matcher", "java.util.regex.Pattern"]
        switch request.mode {
        case .match: imports.insert("java.util.Objects", at: 0)
        case .filter: imports.insert(contentsOf: ["java.util.Arrays", "java.util.List"], at: 0)
        case .replace: break
        }

        var lines = imports.map { "import \($0);" }
        lines += [
            "",
            "public class Main {",
            "    public static void main(String[] args) {",
            "        Pattern pattern = Pattern.compile(\(StringLiteralStyle().literal(pattern))\(flagArgument));",
            "        String text = \(StringLiteralStyle().literal(request.sampleText));",
            "",
        ]

        switch request.mode {
        case .match:
            lines.append("        Matcher matcher = pattern.matcher(text);")
            lines.append("        while (matcher.find()) {")
            lines.append("            System.out.println(matcher.group()); // The whole match")
            for number in request.groups.indices.map({ $0 + 1 }) {
                let group = request.groups[number - 1].map { "matcher.group(\(StringLiteralStyle().literal($0)))" }
                    ?? "matcher.group(\(number))"
                lines.append("            System.out.println(Objects.requireNonNullElse(\(group), \"\")); // \(request.label(forGroup: number))")
            }
            lines.append("        }")
        case .replace:
            lines.append("        String result = pattern.matcher(text).replaceAll(\(StringLiteralStyle().literal(template(for: request))));")
            lines.append("        System.out.println(result);")
        case .filter:
            lines.append("        List<String> kept = Arrays.stream(text.split(\"\\r?\\n\", -1))")
            lines.append("            .filter(line -> \(request.invertsFilter ? "!" : "")pattern.matcher(line).find())")
            lines.append("            .toList();")
            lines.append("        System.out.println(String.join(\"\\n\", kept));")
        }
        lines.append("    }")
        lines.append("}")
        return lines.joined(separator: "\n") + "\n"
    }

    /// A replacement string: `$0`, `$1`, `${name}`, with `\` escaping `$`, `\` and a digit after a group.
    static func template(for request: CodeRequest) -> String {
        let segments = request.replacement.segments
        return segments.indices.map { index in
            switch segments[index] {
            case .literal(let literal):
                var escaped = literal.replacing("\\", with: "\\\\").replacing("$", with: "\\$")
                if index > 0, case .group = segments[index - 1], SegmentLookahead.nextStartsWithDigit(segments, after: index - 1) {
                    escaped = "\\" + escaped
                }
                return escaped
            case .group(let number):
                return "$\(number)"
            case .namedGroup(let name):
                return "${\(name)}"
            }
        }
        .joined()
    }
}

enum CSharpCodeGenerator {
    static func code(for request: CodeRequest) -> String {
        let options = request.options
        var flags: [String] = []
        if options.ignoresCase { flags.append("RegexOptions.IgnoreCase") }
        if options.anchorsMatchLineEndings { flags.append("RegexOptions.Multiline") }
        if options.dotMatchesNewlines { flags.append("RegexOptions.Singleline") }
        if options.allowsExtendedSyntax { flags.append("RegexOptions.IgnorePatternWhitespace") }

        var unsupported: [String] = []
        if request.features.contains(.possessiveQuantifier) { unsupported.append("possessive quantifiers") }

        let pattern = request.pattern(PatternRewrite(namedGroups: .angle))
        let flagArgument = flags.isEmpty ? "" : ", " + flags.joined(separator: " | ")

        // .NET numbers unnamed groups first and named groups after them, so name the named ones.
        func group(_ number: Int) -> String {
            if let name = request.groups[number - 1] { return StringLiteralStyle().literal(name) }
            return String(request.groups[..<number].filter { $0 == nil }.count)
        }

        var lines = request.notes(engine: ".NET", unsupported: unsupported, comment: "//")
        lines += ["using System;"]
        if request.mode == .filter { lines.append("using System.Linq;") }
        lines += [
            "using System.Text.RegularExpressions;",
            "",
            "var regex = new Regex(\(verbatim(pattern))\(flagArgument));",
            "var text = \(StringLiteralStyle().literal(request.sampleText));",
            "",
        ]

        switch request.mode {
        case .match:
            lines.append("foreach (Match match in regex.Matches(text))")
            lines.append("{")
            lines.append("    Console.WriteLine(match.Value); // The whole match")
            for number in request.groups.indices.map({ $0 + 1 }) {
                lines.append("    Console.WriteLine(match.Groups[\(group(number))].Value); // \(request.label(forGroup: number))")
            }
            lines.append("}")
        case .replace:
            let segments = request.replacement.segments
            let template = segments.map { segment in
                switch segment {
                case .literal(let literal): literal.replacing("$", with: "$$")
                case .group(0): "$0"
                case .group(let number): request.groups[number - 1].map { "${\($0)}" } ?? "${\(group(number))}"
                case .namedGroup(let name): "${\(name)}"
                }
            }
            .joined()
            lines.append("var result = regex.Replace(text, \(verbatim(template)));")
            lines.append("Console.WriteLine(result);")
        case .filter:
            lines.append("var kept = text.Split('\\n')")
            lines.append("    .Select(line => line.TrimEnd('\\r'))")
            lines.append("    .Where(line => \(request.invertsFilter ? "!" : "")regex.IsMatch(line));")
            lines.append("Console.WriteLine(string.Join(\"\\n\", kept));")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// A verbatim @"…" string, where only `"` needs doubling.
    static func verbatim(_ string: String) -> String {
        "@\"" + string.replacing("\"", with: "\"\"") + "\""
    }
}

enum KotlinCodeGenerator {
    static func code(for request: CodeRequest) -> String {
        let options = request.options
        var regexOptions: [String] = []
        if options.ignoresCase { regexOptions.append("RegexOption.IGNORE_CASE") }
        if options.anchorsMatchLineEndings { regexOptions.append("RegexOption.MULTILINE") }
        // Only IGNORE_CASE and MULTILINE are on every platform, so the rest are inline flags.
        var flags = ""
        if options.dotMatchesNewlines { flags += "s" }
        if options.allowsExtendedSyntax { flags += "x" }
        let pattern = (flags.isEmpty ? "" : "(?\(flags))") + request.pattern(PatternRewrite(namedGroups: .angle))

        let style = StringLiteralStyle(extraEscapes: ["$": "\\$"])
        let optionArgument = switch regexOptions.count {
        case 0: ""
        case 1: ", \(regexOptions[0])"
        default: ", setOf(\(regexOptions.joined(separator: ", ")))"
        }

        var lines = [
            "fun main() {",
            "    val regex = Regex(\(style.literal(pattern))\(optionArgument))",
            "    val text = \(style.literal(request.sampleText))",
            "",
        ]

        switch request.mode {
        case .match:
            lines.append("    for (match in regex.findAll(text)) {")
            lines.append("        println(match.value) // The whole match")
            for number in request.groups.indices.map({ $0 + 1 }) {
                lines.append("        println(match.groupValues[\(number)]) // \(request.label(forGroup: number))")
            }
            lines.append("    }")
        case .replace:
            let body = request.numberedReplacementSegments.map { segment in
                switch segment {
                case .literal(let literal): String(style.literal(literal).dropFirst().dropLast())
                case .group(0): "${match.value}"
                case .group(let number): "${match.groupValues[\(number)]}"
                case .namedGroup(let name): "${match.groups[\"\(name)\"]?.value.orEmpty()}"
                }
            }
            .joined()
            lines.append("    val result = regex.replace(text) { match -> \"\(body)\" }")
            lines.append("    println(result)")
        case .filter:
            lines.append("    val lines = text.split(Regex(\"\\r?\\n\"))")
            lines.append("    val kept = lines.\(request.invertsFilter ? "filterNot" : "filter") { regex.containsMatchIn(it) }")
            lines.append("    println(kept.joinToString(\"\\n\"))")
        }
        lines.append("}")
        return lines.joined(separator: "\n") + "\n"
    }
}

enum CppCodeGenerator {
    static func code(for request: CodeRequest) -> String {
        let options = request.options
        let features = request.features
        var flags = ["std::regex::ECMAScript"]
        if options.ignoresCase { flags.append("std::regex::icase") }
        if options.anchorsMatchLineEndings { flags.append("std::regex::multiline") }

        var unsupported: [String] = []
        if features.contains(.lookbehind) { unsupported.append("lookbehinds") }
        if !features.isDisjoint(with: [.atomicGroup, .possessiveQuantifier]) {
            unsupported.append("atomic groups or possessive quantifiers")
        }
        if features.contains(.unicodeProperty) { unsupported.append("\\p{…} properties") }
        if features.contains(.inlineFlags) { unsupported.append("inline flags such as (?i)") }
        if features.contains(.absoluteAnchor) { unsupported.append("\\A, \\z, \\Z or \\G") }

        // std::regex has no names, no "ignore whitespace" and no "dot matches newlines",
        // so the pattern is rewritten to do without them.
        let rewrite = PatternRewrite(
            namedGroups: .unnamed,
            stripsExtendedSyntax: true,
            dotMatchesNewlines: options.dotMatchesNewlines
        )
        let pattern = request.pattern(rewrite)
        let text = StringLiteralStyle(control: { "\\" + String($0, radix: 8).leftPadded(to: 3) }).literal(request.sampleText)

        var includes = ["<iostream>", "<regex>", "<string>"]
        if request.mode == .filter { includes.insert("<sstream>", at: 2) }

        var lines = request.notes(engine: "std::regex", unsupported: unsupported, comment: "//")
        lines += includes.map { "#include \($0)" }
        lines += [
            "",
            "int main() {",
            "    const std::regex regex(\(rawLiteral(pattern)), \(flags.joined(separator: " | ")));",
            "    const std::string text = \(text);",
            "",
        ]

        switch request.mode {
        case .match:
            lines.append("    for (auto it = std::sregex_iterator(text.begin(), text.end(), regex); it != std::sregex_iterator(); ++it) {")
            lines.append("        const std::smatch& match = *it;")
            lines.append("        std::cout << match.str(0) << '\\n'; // The whole match")
            for number in request.groups.indices.map({ $0 + 1 }) {
                lines.append("        std::cout << match.str(\(number)) << '\\n'; // \(request.label(forGroup: number))")
            }
            lines.append("    }")
        case .replace:
            lines.append("    const std::string result = std::regex_replace(text, regex, \(StringLiteralStyle().literal(template(for: request))));")
            lines.append("    std::cout << result << '\\n';")
        case .filter:
            lines.append("    std::istringstream stream(text);")
            lines.append("    std::string line, kept;")
            lines.append("    bool first = true;")
            lines.append("    while (std::getline(stream, line)) {")
            lines.append("        if (!line.empty() && line.back() == '\\r') line.pop_back();")
            lines.append("        if (\(request.invertsFilter ? "!" : "")std::regex_search(line, regex)) {")
            lines.append("            kept += (first ? \"\" : \"\\n\") + line;")
            lines.append("            first = false;")
            lines.append("        }")
            lines.append("    }")
            lines.append("    std::cout << kept << '\\n';")
        }
        lines.append("}")
        return lines.joined(separator: "\n") + "\n"
    }

    /// A raw R"(…)" string, with a delimiter if the pattern holds `)"`.
    static func rawLiteral(_ string: String) -> String {
        var delimiter = ""
        while string.contains(")\(delimiter)\"") {
            delimiter += "x"
        }
        return "R\"\(delimiter)(\(string))\(delimiter)\""
    }

    /// An ECMAScript format string: `$&`, `$1` or `$01`, and `$$`.
    static func template(for request: CodeRequest) -> String {
        let segments = request.numberedReplacementSegments
        return segments.indices.map { index in
            switch segments[index] {
            case .literal(let literal):
                return literal.replacing("$", with: "$$")
            case .group(0):
                return "$&"
            case .group(let number):
                return number < 10 && SegmentLookahead.nextStartsWithDigit(segments, after: index)
                    ? "$0\(number)" : "$\(number)"
            case .namedGroup(let name):
                return "$<\(name)>"
            }
        }
        .joined()
    }
}

/// A `${1}` / `${name}` / `$$` replacement, as Go and Rust read it.
enum DollarBraceTemplate {
    static func make(_ request: CodeRequest) -> String {
        request.replacement.segments.map { segment in
            switch segment {
            case .literal(let literal): literal.replacing("$", with: "$$")
            case .group(let number): "${\(number)}"
            case .namedGroup(let name): "${\(name)}"
            }
        }
        .joined()
    }
}

private extension String {
    func leftPadded(to width: Int) -> String {
        String(repeating: "0", count: max(0, width - count)) + self
    }
}
