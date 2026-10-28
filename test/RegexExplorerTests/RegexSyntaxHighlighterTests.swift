// Copyright © 2026 Robert Hedin
// All Rights Reserved.

import Testing
@testable import RegexExplorer

struct RegexSyntaxHighlighterTests {
    /// Each token as its kind and the text it covers, which reads more easily than offsets.
    private func runs(_ pattern: String, extended: Bool = false) -> [(RegexSyntaxKind, String)] {
        let characters = Array(pattern)
        return RegexSyntaxHighlighter.tokens(in: pattern, allowsExtendedSyntax: extended).map {
            ($0.kind, String(characters[$0.range]))
        }
    }

    private func expectRuns(_ pattern: String, extended: Bool = false, _ expected: [(RegexSyntaxKind, String)]) {
        let actual = runs(pattern, extended: extended)
        #expect(actual.map(\.0) == expected.map(\.0), "kinds for \(pattern)")
        #expect(actual.map(\.1) == expected.map(\.1), "text for \(pattern)")
    }

    @Test func literalsHaveNoTokens() {
        #expect(RegexSyntaxHighlighter.tokens(in: "hello world").isEmpty)
        #expect(RegexSyntaxHighlighter.tokens(in: "").isEmpty)
    }

    @Test func colorsTheEmailStarter() {
        expectRuns(#"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#, [
            (.anchor, "^"),
            (.characterClass, "[a-zA-Z0-9._%+-]"),
            (.quantifier, "+"),
            (.characterClass, "[a-zA-Z0-9.-]"),
            (.quantifier, "+"),
            (.escape, #"\."#),
            (.characterClass, "[a-zA-Z]"),
            (.quantifier, "{2,}"),
            (.anchor, "$"),
        ])
    }

    @Test func groupPrefixesBelongToTheGroup() {
        expectRuns(#"(?<year>\d{4})(?:a|b)(?=c)(?<!d)(?i)"#, [
            (.group(1), "(?<year>"),
            (.escape, #"\d"#),
            (.quantifier, "{4}"),
            (.group(1), ")"),
            (.group(nil), "(?:"),
            (.alternation, "|"),
            (.group(nil), ")(?="),
            (.group(nil), ")(?<!"),
            (.group(nil), ")(?i)"),
        ])
    }

    @Test func groupsAreNumberedLikeTheResults() {
        expectRuns("((a)(?:b)(?<n>c))(d)", [
            (.group(1), "("),
            (.group(2), "("),
            (.group(2), ")"),
            (.group(nil), "(?:"),
            (.group(nil), ")"),
            (.group(3), "(?<n>"),
            (.group(3), ")"),
            (.group(1), ")"),
            (.group(4), "("),
            (.group(4), ")"),
        ])
    }

    @Test func groupNumbersAgreeWithTheScanner() {
        let pattern = #"(?<year>\d{4})-(\d{2})(?:-(?'day'\d{2}))?(?P<z>z)(?=x)"#
        var numbers: [Int] = []
        for token in RegexSyntaxHighlighter.tokens(in: pattern) {
            if case .group(let number?) = token.kind, !numbers.contains(number) { numbers.append(number) }
        }
        #expect(numbers == Array(1...CaptureGroupScanner.groups(in: pattern).count))
    }

    @Test func anUnmatchedCloseParenDoesNotCapture() {
        expectRuns("a)", [(.group(nil), ")")])
    }

    @Test func quantifiersIncludeLazyAndPossessiveMarks() {
        expectRuns("a*?b++c??d{1,3}?", [
            (.quantifier, "*?"),
            (.quantifier, "++"),
            (.quantifier, "??"),
            (.quantifier, "{1,3}?"),
        ])
    }

    @Test func aBraceThatIsNotAQuantifierIsLiteral() {
        #expect(RegexSyntaxHighlighter.tokens(in: "a{b}").isEmpty)
        #expect(RegexSyntaxHighlighter.tokens(in: "a{").isEmpty)
        #expect(RegexSyntaxHighlighter.tokens(in: "a{,}").isEmpty)
    }

    @Test func classesKeepEscapesAndLiteralBrackets() {
        expectRuns(#"[]a\]b][^]]"#, [
            (.characterClass, "[]a"),
            (.escape, #"\]"#),
            (.characterClass, "b][^]]"),
        ])
    }

    @Test func classesCanNestAndHoldPosixClasses() {
        expectRuns("[a[bc]][[:alpha:]]x", [
            (.characterClass, "[a[bc]][[:alpha:]]"),
        ])
    }

    @Test func specialCharactersInsideAClassAreNotOperators() {
        expectRuns("[(|)*^$]", [(.characterClass, "[(|)*^$]")])
    }

    @Test func anchorEscapesAreAnchors() {
        expectRuns(#"\bword\B\A\z"#, [
            (.anchor, #"\b"#),
            (.anchor, #"\B\A\z"#),
        ])
    }

    @Test func longerEscapesAreOneToken() {
        expectRuns(#"\p{L}x\x{1F600}y\k<name>z\12w\Q.*\Ev"#, [
            (.escape, #"\p{L}"#),
            (.escape, #"\x{1F600}"#),
            (.escape, #"\k<name>"#),
            (.escape, #"\12"#),
            (.escape, #"\Q.*\E"#),
        ])
    }

    @Test func aTrailingBackslashIsAnEscape() {
        expectRuns(#"a\"#, [(.escape, #"\"#)])
    }

    @Test func commentsNeedExtendedSyntaxUnlessInline() {
        expectRuns("a # note\nb", extended: true, [(.comment, "# note")])
        #expect(RegexSyntaxHighlighter.tokens(in: "a # note").isEmpty)
        expectRuns("a(?#note)b", [(.comment, "(?#note)")])
    }

    @Test func halfTypedPatternsStillColor() {
        expectRuns("(?<na", [(.group(1), "(?<na")])
        expectRuns("[abc", [(.characterClass, "[abc")])
        expectRuns("(a", [(.group(1), "(")])
    }

    @Test func tokensNeverOverlapAndStayInBounds() {
        for starter in StarterRegexes.make() {
            let tokens = RegexSyntaxHighlighter.tokens(in: starter.pattern)
            var previousEnd = 0
            for token in tokens {
                #expect(token.range.lowerBound >= previousEnd, "\(starter.name)")
                #expect(token.range.upperBound <= starter.pattern.count, "\(starter.name)")
                previousEnd = token.range.upperBound
            }
        }
    }
}
