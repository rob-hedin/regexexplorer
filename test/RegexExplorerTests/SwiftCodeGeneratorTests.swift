import Testing
@testable import RegexExplorer

struct SwiftCodeGeneratorTests {
    @Test func scannerFindsCaptureGroups() {
        let pattern = #"(?<name>a)(b)(?:c)(?=d)(?<!e)[(]\(f\)(?'q'g)(?P<r>h)"#
        #expect(CaptureGroupScanner.groups(in: pattern) == ["name", nil, "q", "r"])
    }

    @Test func scannerSkipsCommentsInExtendedSyntax() {
        #expect(CaptureGroupScanner.groups(in: "(a) # (b)\n(c)", allowsExtendedSyntax: true) == [nil, nil])
        #expect(CaptureGroupScanner.groups(in: "(a) # (b)\n(c)").count == 3)
    }

    @Test func scannerAgreesWithSwiftRegex() throws {
        let pattern = #"(?<year>\d{4})-(\d{2})(?:-(?<day>\d{2}))?"#
        let match = try #require(try Regex(pattern).firstMatch(in: "2024-06-10"))
        #expect(CaptureGroupScanner.groups(in: pattern) == match.output.dropFirst().map(\.name))
    }

    @Test(arguments: [
        ("abc", "#/abc/#"),
        ("a/b", "#/a/b/#"),
        (" a", "#/ a/#"),
        ("*a", "#/*a/#"),
        ("a/#b", "##/a/#b/##"),
    ])
    func literalUsesTheFewestHashes(pattern: String, literal: String) {
        #expect(SwiftCodeGenerator.regexLiteral(for: pattern) == literal)
    }

    @Test func multiLinePatternHasNoLiteral() {
        #expect(SwiftCodeGenerator.regexLiteral(for: "a\nb") == nil)
    }

    @Test func stringLiteralEscapesSpecialCharacters() {
        #expect(SwiftCodeGenerator.stringLiteral("a\"b\\c\nd") == #""a\"b\\c\nd""#)
    }

    @Test func matchModeCode() {
        let regex = SavedRegex(
            name: "Domain",
            pattern: #"(?<name>[a-z]+)\.(?<tld>[a-z]+)"#,
            sampleText: "swift.org",
            options: RegexOptions(ignoresCase: true)
        )
        #expect(SwiftCodeGenerator.code(for: regex) == #"""
            let regex = #/(?<name>[a-z]+)\.(?<tld>[a-z]+)/#
                .ignoresCase()

            let text = "swift.org"

            for match in text.matches(of: regex) {
                print(match.output.0) // The whole match
                print(match.output.name as Substring? ?? "") // Group 1
                print(match.output.tld as Substring? ?? "") // Group 2
            }

            """#)
    }

    @Test func replaceModeCodeInterpolatesGroups() {
        let regex = SavedRegex(name: "Domain", pattern: #"(?<name>[a-z]+)\.([a-z]+)"#, mode: .replace, replacement: #"<${name}.$2> "$$""#)
        #expect(SwiftCodeGenerator.code(for: regex).contains(#"""
            let result = text.replacing(regex) { match in
                let groups = AnyRegexOutput(match)
                return "<\(groups["name"]?.substring ?? "").\(groups[2].substring ?? "")> \"$\""
            }
            """#))
    }

    @Test func replaceModeWithoutGroupsUsesAPlainString() {
        let regex = SavedRegex(name: "Digits", pattern: #"\d"#, mode: .replace, replacement: "#")
        #expect(SwiftCodeGenerator.code(for: regex).contains(##"let result = text.replacing(regex, with: "#")"##))
    }

    @Test func filterModeCode() {
        let regex = SavedRegex(name: "Digits", pattern: #"\d"#, mode: .filter, invertsFilter: true)
        #expect(SwiftCodeGenerator.code(for: regex).contains("let kept = lines.filter { !$0.contains(regex) }"))
    }

    @Test func multiLinePatternCompilesAtRunTime() {
        let regex = SavedRegex(name: "Spaced", pattern: "a # letter\nb", options: RegexOptions(allowsExtendedSyntax: true))
        let code = SwiftCodeGenerator.code(for: regex)
        #expect(code.contains(#"let regex = try Regex("(?x)a # letter\nb")"#))
        #expect(code.contains(#"print(match.output[0].substring ?? "") // The whole match"#))
    }
}
