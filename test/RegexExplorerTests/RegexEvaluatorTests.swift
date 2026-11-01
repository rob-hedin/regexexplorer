// Copyright © 2026 Robert Hedin

import Foundation
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

    @Test func backgroundEvaluationMatchesTheSynchronousOne() async {
        let evaluation = await RegexEvaluator.evaluateInBackground(pattern: #"\d+"#, options: RegexOptions(), in: "a1 b22")
        #expect(evaluation == RegexEvaluator.evaluate(pattern: #"\d+"#, options: RegexOptions(), in: "a1 b22"))
    }

    @Test func cancellingABackgroundEvaluationReturnsWithoutWaitingForIt() async {
        // Catastrophic backtracking: this would run for a very long time.
        let text = String(repeating: "a", count: 40) + "!"
        let task = Task {
            await RegexEvaluator.evaluateInBackground(pattern: "^(a+)+$", options: RegexOptions(), in: text)
        }
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        #expect(await task.value == nil)
    }

    @Test func busyWorkersQueueNewWorkAndSkipCancelledRequests() async {
        let workers = MatchWorkers(threadLimit: 1)
        let slow = Task {
            await workers.run {
                Thread.sleep(forTimeInterval: 0.3)
                return .noPattern
            }
        }
        try? await Task.sleep(for: .milliseconds(50))
        // The only thread is busy, so these wait in the queue.
        let skipped = Task { await workers.run { .invalidPattern("should not run") } }
        let queued = Task { await workers.run { .matches([], truncated: false) } }
        try? await Task.sleep(for: .milliseconds(50))
        skipped.cancel()
        slow.cancel()

        #expect(await slow.value == nil)
        #expect(await skipped.value == nil)
        // It runs once the slow work finishes, on the same thread.
        #expect(await queued.value == .matches([], truncated: false))
    }

    @Test func matchesAgreeWithSwiftsOwnMatching() throws {
        // Including empty matches, which the search has to step past.
        for (pattern, text) in [("a*", "baab"), (#"\b"#, "ab cd"), ("^", "x\ny"), ("(a)|b", "abba")] {
            let expected = try "\(text)".matches(of: Regex(pattern)).map(\.range)
            guard case .matches(let matches, false) = RegexEvaluator.evaluate(pattern: pattern, options: RegexOptions(), in: text) else {
                Issue.record("Expected matches for \(pattern)")
                continue
            }
            #expect(matches.map(\.range) == expected, "\(pattern)")
        }
    }

    @Test func matchLimitStopsTheSearch() {
        // Finding all two million matches would take far longer than this test allows.
        let text = String(repeating: "a", count: 2_000_000)
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            _ = RegexEvaluator.evaluate(pattern: "a", options: RegexOptions(), in: text, matchLimit: 10)
        }
        #expect(elapsed < .seconds(1))
    }
}
