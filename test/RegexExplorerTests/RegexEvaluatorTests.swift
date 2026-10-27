import Testing
@testable import RegexExplorer

struct RegexEvaluatorTests {
    /// The matched text of each match, for compact assertions.
    private func matchedText(_ pattern: String, _ text: String, options: RegexOptions = RegexOptions()) -> [String] {
        guard case .matches(let matches, _) = RegexEvaluator.evaluate(pattern: pattern, options: options, in: text) else {
            Issue.record("Expected matches for \(pattern)")
            return []
        }
        return matches.map { String(text[$0.range]) }
    }

    @Test func emptyPatternHasNothingToMatch() {
        #expect(RegexEvaluator.evaluate(pattern: "", options: RegexOptions(), in: "abc") == .noPattern)
    }

    @Test func invalidPatternReportsAnError() {
        guard case .invalidPattern(let message) = RegexEvaluator.evaluate(pattern: "(abc", options: RegexOptions(), in: "abc") else {
            Issue.record("Expected an invalid pattern")
            return
        }
        #expect(!message.isEmpty)
    }

    @Test func findsEveryMatch() {
        #expect(matchedText(#"\d+"#, "a1 b22 c333") == ["1", "22", "333"])
    }

    @Test func noMatchesIsAnEmptyList() {
        #expect(RegexEvaluator.evaluate(pattern: "z", options: RegexOptions(), in: "abc") == .matches([], truncated: false))
    }

    @Test func reportsNumberedAndNamedGroups() throws {
        let text = "Released 2024-06-10"
        let evaluation = RegexEvaluator.evaluate(pattern: #"(?<year>\d{4})-(\d{2})-(\d{2})"#, options: RegexOptions(), in: text)
        guard case .matches(let matches, _) = evaluation else {
            Issue.record("Expected matches")
            return
        }
        let groups = try #require(matches.first).groups
        #expect(groups.map(\.number) == [1, 2, 3])
        #expect(groups.map(\.name) == ["year", nil, nil])
        #expect(groups.map { $0.range.map { String(text[$0]) } } == ["2024", "06", "10"])
    }

    @Test func groupThatDoesNotTakePartHasNoRange() throws {
        let evaluation = RegexEvaluator.evaluate(pattern: "a(b)?c", options: RegexOptions(), in: "ac")
        guard case .matches(let matches, _) = evaluation else {
            Issue.record("Expected matches")
            return
        }
        #expect(try #require(matches.first).groups.first?.range == nil)
    }

    @Test func ignoresCaseOption() {
        #expect(matchedText("abc", "ABC").isEmpty)
        #expect(matchedText("abc", "ABC", options: RegexOptions(ignoresCase: true)) == ["ABC"])
    }

    @Test func anchorsMatchLineEndingsOption() {
        let text = "one\ntwo\nthree"
        #expect(matchedText("^t.*$", text).isEmpty)
        #expect(matchedText("^t.*$", text, options: RegexOptions(anchorsMatchLineEndings: true)) == ["two", "three"])
    }

    @Test func dotMatchesNewlinesOption() {
        #expect(matchedText("a.b", "a\nb").isEmpty)
        #expect(matchedText("a.b", "a\nb", options: RegexOptions(dotMatchesNewlines: true)) == ["a\nb"])
    }

    @Test func extendedSyntaxOption() {
        let pattern = #"\d+  # digits"#
        #expect(matchedText(pattern, "42").isEmpty)
        #expect(matchedText(pattern, "42", options: RegexOptions(allowsExtendedSyntax: true)) == ["42"])
    }

    @Test func simpleWordBoundariesOption() {
        // Unicode word rules treat "can't" as one word; simple rules break at the apostrophe.
        #expect(matchedText(#"\bt\b"#, "can't").isEmpty)
        #expect(matchedText(#"\bt\b"#, "can't", options: RegexOptions(usesSimpleWordBoundaries: true)) == ["t"])
    }

    @Test func inlineFlagsStillWorkWhenOptionIsOff() {
        #expect(matchedText("(?i)abc", "ABC") == ["ABC"])
    }

    @Test func limitsTheNumberOfMatches() {
        let evaluation = RegexEvaluator.evaluate(pattern: "a", options: RegexOptions(), in: "aaaaa", matchLimit: 3)
        guard case .matches(let matches, let truncated) = evaluation else {
            Issue.record("Expected matches")
            return
        }
        #expect(matches.count == 3)
        #expect(truncated)
    }
}
