import Foundation

// Writes the code every language generates for a set of sample regexes, with the output
// the editor shows for each, so check.sh can run the code and compare. Build and run it
// with run.sh.

struct Sample {
    let name: String
    let regex: SavedRegex
}

let samples: [Sample] = [
    Sample(name: "email-match", regex: SavedRegex(
        name: "Email", pattern: #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#,
        sampleText: "alice@example.com\nnot an email\nbob.smith@mail.co.uk",
        options: RegexOptions(anchorsMatchLineEndings: true))),
    Sample(name: "date-groups", regex: SavedRegex(
        name: "Date", pattern: #"(?<year>\d{4})-(\d{2})(?:-(?<day>\d{2}))?"#,
        sampleText: "2024-06-10 and 2025-01")),
    Sample(name: "replace-numbered", regex: SavedRegex(
        name: "Numbered", pattern: #"(\w+)@(\w+)\.com"#,
        sampleText: "joe@acme.com, ann@corp.com",
        mode: .replace, replacement: #"$2 at $1 ($$5) ${1}9 $12 \ "q" 'x' #{y} @z %s {}"#)),
    Sample(name: "replace-named", regex: SavedRegex(
        name: "Named", pattern: #"(?<first>\w+) (?<last>\w+)"#,
        sampleText: "Ada Lovelace\nAlan Turing",
        mode: .replace, replacement: "${last}, ${first}!")),
    Sample(name: "replace-whole", regex: SavedRegex(
        name: "Whole", pattern: #"\d+"#, sampleText: "a1b22c333",
        mode: .replace, replacement: "<$0>")),
    Sample(name: "replace-literal", regex: SavedRegex(
        name: "Literal", pattern: "cat", sampleText: "cat scattered",
        mode: .replace, replacement: #"d\o$g"#)),
    Sample(name: "replace-optional", regex: SavedRegex(
        name: "Optional", pattern: "(a)?b", sampleText: "ab b",
        mode: .replace, replacement: "[$1]")),
    Sample(name: "filter", regex: SavedRegex(
        name: "Filter", pattern: "error|warn", sampleText: "INFO start\nERROR disk\nWarn: low\nok",
        options: RegexOptions(ignoresCase: true), mode: .filter)),
    Sample(name: "filter-inverted", regex: SavedRegex(
        name: "Filter inverted", pattern: "error|warn", sampleText: "INFO start\nERROR disk\nWarn: low\nok",
        options: RegexOptions(ignoresCase: true), mode: .filter, invertsFilter: true)),
    Sample(name: "filter-anchored", regex: SavedRegex(
        name: "Comments", pattern: "^#", sampleText: "# one\ncode\n# two", mode: .filter)),
    Sample(name: "specials-match", regex: SavedRegex(
        name: "Specials", pattern: #"[/"'`$#@{}\\]+"#,
        sampleText: #"a/b"c'd`e$f#g@h{i}j\k"#)),
    Sample(name: "dotall-extended", regex: SavedRegex(
        name: "Extended", pattern: "start (.+?) end  # the middle",
        sampleText: "start one\ntwo end",
        options: RegexOptions(dotMatchesNewlines: true, allowsExtendedSyntax: true))),
    Sample(name: "anchors-whole-text", regex: SavedRegex(
        name: "Whole text", pattern: #"^b\w+$"#, sampleText: "alpha\nbeta")),
    Sample(name: "mixed-named", regex: SavedRegex(
        name: "Mixed", pattern: #"(?<word>\w+)-(\d+)"#, sampleText: "abc-12 x-9")),
    Sample(name: "unicode-text", regex: SavedRegex(
        name: "Unicode", pattern: "w.rld", sampleText: "hello wörld\ttab")),
    Sample(name: "lookbehind", regex: SavedRegex(
        name: "Lookbehind", pattern: #"(?<=\$)\d+"#, sampleText: "cost $42 or 7")),
]

func fileName(for language: CodeLanguage) -> String {
    switch language {
    case .csharp: "csharp.cs"
    case .cpp: "cpp.cpp"
    case .go: "go.go"
    case .java: "Main.java"
    case .javascript: "javascript.js"
    case .kotlin: "kotlin.kt"
    case .perl: "perl.pl"
    case .php: "php.php"
    case .python: "python.py"
    case .r: "r.R"
    case .ruby: "ruby.rb"
    case .rust: "rust.rs"
    case .swift5: "swift5.swift"
    case .swift6: "swift6.swift"
    }
}

/// What the generated code should print, worked out the way the editor works it out.
func expectedOutput(for regex: SavedRegex) throws -> String {
    let compiled: Regex<AnyRegexOutput>
    do {
        compiled = try RegexEvaluator.makeRegex(pattern: regex.pattern, options: regex.options)
    } catch {
        // Swift's Regex can't compile some syntax (such as lookbehind) that the other
        // languages can, so work out what they should print with ICU instead.
        return try icuExpectedOutput(for: regex)
    }
    guard case .matches(let matches, _) = RegexEvaluator.evaluate(
        pattern: regex.pattern, options: regex.options, in: regex.sampleText, matchLimit: .max
    ) else { throw CocoaError(.featureUnsupported) }
    let text = regex.sampleText
    switch regex.mode {
    case .match:
        var lines: [String] = []
        for match in matches {
            lines.append(String(text[match.range]))
            lines += match.groups.map { $0.range.map { String(text[$0]) } ?? "" }
        }
        return lines.map { $0 + "\n" }.joined()
    case .replace:
        return RegexReplacer.replace(in: text, matches: matches, template: regex.replacement).text + "\n"
    case .filter:
        // The generated code matches each line on its own.
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        let kept = lines.filter { $0.contains(compiled) != regex.invertsFilter }
        return kept.joined(separator: "\n") + "\n"
    }
}

/// What a match-mode sample should print, worked out with NSRegularExpression.
func icuExpectedOutput(for regex: SavedRegex) throws -> String {
    guard regex.mode == .match else { throw CocoaError(.featureUnsupported) }
    var options: NSRegularExpression.Options = []
    if regex.options.ignoresCase { options.insert(.caseInsensitive) }
    if regex.options.anchorsMatchLineEndings { options.insert(.anchorsMatchLines) }
    if regex.options.dotMatchesNewlines { options.insert(.dotMatchesLineSeparators) }
    if regex.options.allowsExtendedSyntax { options.insert(.allowCommentsAndWhitespace) }
    let compiled = try NSRegularExpression(pattern: regex.pattern, options: options)
    let text = regex.sampleText as NSString
    var lines: [String] = []
    for match in compiled.matches(in: regex.sampleText, range: NSRange(location: 0, length: text.length)) {
        for index in 0..<match.numberOfRanges {
            let range = match.range(at: index)
            lines.append(range.location == NSNotFound ? "" : text.substring(with: range))
        }
    }
    return lines.map { $0 + "\n" }.joined()
}

let output = URL(filePath: CommandLine.arguments.dropFirst().first ?? "build/code-samples", directoryHint: .isDirectory)
for sample in samples {
    let directory = output.appending(path: sample.name, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try expectedOutput(for: sample.regex).write(to: directory.appending(path: "expected.txt"), atomically: true, encoding: .utf8)
    for language in CodeLanguage.allCases {
        try CodeGenerator.code(for: sample.regex, language: language)
            .write(to: directory.appending(path: fileName(for: language)), atomically: true, encoding: .utf8)
    }
}
print("Wrote \(samples.count) samples to \(output.path())")
