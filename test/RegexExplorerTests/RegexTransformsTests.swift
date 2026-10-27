import Testing
@testable import RegexExplorer

struct RegexTransformsTests {
    private let domainPattern = #"(?<name>[a-z0-9-]+)\.(?<tld>[a-z]{2,})"#

    private func matches(_ pattern: String, in text: String, options: RegexOptions = RegexOptions()) -> [RegexMatch] {
        guard case .matches(let matches, _) = RegexEvaluator.evaluate(pattern: pattern, options: options, in: text) else {
            Issue.record("Expected matches for \(pattern)")
            return []
        }
        return matches
    }

    private func replace(_ pattern: String, in text: String, with template: String) -> String {
        RegexReplacer.replace(in: text, matches: matches(pattern, in: text), template: template).text
    }

    // MARK: Replacement templates

    @Test func templateParsesGroupReferences() {
        let template = ReplacementTemplate("<$0|$1|${2}|${name}|$$>", groupCount: 2, groupNames: ["name"])
        #expect(template.segments == [
            .literal("<"), .group(0), .literal("|"), .group(1), .literal("|"), .group(2),
            .literal("|"), .namedGroup("name"), .literal("|$>"),
        ])
    }

    @Test func templateKeepsUnknownReferencesAsTyped() {
        let template = ReplacementTemplate("$3 ${9} ${nope} $x $", groupCount: 2, groupNames: [])
        #expect(template.segments == [.literal("$3 ${9} ${nope} $x $")])
    }

    @Test func templateTakesTheLongestExistingGroupNumber() {
        #expect(ReplacementTemplate("$12", groupCount: 1, groupNames: []).segments == [.group(1), .literal("2")])
        #expect(ReplacementTemplate("$12", groupCount: 12, groupNames: []).segments == [.group(12)])
    }

    @Test func replacesEachMatchUsingGroups() {
        let text = "Email support@example.com, or see swift.org"
        #expect(replace(domainPattern, in: text, with: "<${name}.${tld}>") == "Email support@<example.com>, or see <swift.org>")
        #expect(replace(domainPattern, in: text, with: "$2:$1") == "Email support@com:example, or see org:swift")
    }

    @Test func reportsWhereReplacementsLanded() {
        let text = "Email support@example.com, or see swift.org"
        let result = RegexReplacer.replace(in: text, matches: matches(domainPattern, in: text), template: "<$0>")
        #expect(result.replacedRanges == [14..<27, 36..<47])
    }

    @Test func groupThatDidNotTakePartReplacesWithNothing() {
        #expect(replace("a(b)?c", in: "ac abc", with: "[$1]") == "[] [b]")
    }

    @Test func noMatchesLeavesTextUnchanged() {
        let result = RegexReplacer.replace(in: "hello", matches: [], template: "x")
        #expect(result == ReplacementResult(text: "hello", replacedRanges: []))
    }

    // MARK: Line filter

    private let lines = """
        Email support@example.com
        Call 555-0100 after 9am
        See swift.org and apple.com for docs
        Nothing to find here: hello world
        """

    @Test func keepsLinesWithAMatch() {
        let result = LineFilter.filter(lines, matches: matches(domainPattern, in: lines), inverted: false)
        #expect(result.lines.map(\.number) == [1, 3])
        #expect(result.totalLineCount == 4)
        #expect(result.lines.map(\.matchRanges) == [[14..<25], [4..<13, 18..<27]])
        #expect(result.text == "Email support@example.com\nSee swift.org and apple.com for docs")
    }

    @Test func invertedKeepsLinesWithoutAMatch() {
        let result = LineFilter.filter(lines, matches: matches(domainPattern, in: lines), inverted: true)
        #expect(result.lines.map(\.number) == [2, 4])
        #expect(result.lines.allSatisfy(\.matchRanges.isEmpty))
    }

    @Test func finalNewlineDoesNotAddALine() {
        let result = LineFilter.filter("a\nb\n", matches: matches("b", in: "a\nb\n"), inverted: false)
        #expect(result.totalLineCount == 2)
        #expect(result.lines.map(\.number) == [2])
    }

    @Test func matchSpanningLinesKeepsEachOfThem() {
        let text = "start\nmiddle\nend\nother"
        let found = matches("start.*end", in: text, options: RegexOptions(dotMatchesNewlines: true))
        let result = LineFilter.filter(text, matches: found, inverted: false)
        #expect(result.lines.map(\.number) == [1, 2, 3])
        #expect(result.lines[1].matchRanges == [0..<6])
    }

    @Test func emptyMatchKeepsItsLine() {
        let text = "a\n\nb"
        let found = matches("^$", in: text, options: RegexOptions(anchorsMatchLineEndings: true))
        #expect(LineFilter.filter(text, matches: found, inverted: false).lines.map(\.number) == [2])
    }
}
