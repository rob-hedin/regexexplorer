// Copyright © 2026 Robert Hedin
// All Rights Reserved.

import SwiftUI
import Testing
@testable import RegexExplorer

struct MatchPresentationTests {
    private func matches(_ pattern: String, in text: String) -> [RegexMatch] {
        guard case .matches(let matches, _) = RegexEvaluator.evaluate(pattern: pattern, options: RegexOptions(), in: text) else {
            Issue.record("Expected matches for \(pattern)")
            return []
        }
        return matches
    }

    @Test func columnsUseGroupNamesOrNumbers() {
        let found = matches(#"(?<name>[a-z]+)\.([a-z]+)"#, in: "swift.org")
        #expect(MatchPresentation.groupColumns(for: found).map(\.title) == ["name", "Group 2"])
    }

    @Test func noMatchesMeansNoColumns() {
        #expect(MatchPresentation.groupColumns(for: []).isEmpty)
    }

    @Test func rowsListEachMatchWithGroupsAndPosition() {
        let text = "Email support@example.com, or see swift.org"
        let rows = MatchPresentation.rows(for: matches(#"(?<name>[a-z0-9-]+)\.(?<tld>[a-z]{2,})"#, in: text), in: text)
        #expect(rows.map(\.text) == ["example.com", "swift.org"])
        #expect(rows.map(\.groupValues) == [["example", "com"], ["swift", "org"]])
        #expect(rows.map(\.position) == ["14–25", "34–43"])
    }

    @Test func groupThatDidNotTakePartHasNoValue() {
        let rows = MatchPresentation.rows(for: matches("a(b)?c", in: "ac"), in: "ac")
        #expect(rows.first?.groupValues == [nil])
    }

    @Test func highlightsOnlyTheMatchedText() {
        let highlighted = MatchPresentation.highlightedText("a1 b2", matches: matches(#"\d"#, in: "a1 b2"))
        let highlightedRuns = highlighted.runs.filter { $0.backgroundColor != nil }
        #expect(highlightedRuns.map { String(highlighted[$0.range].characters) } == ["1", "2"])
    }
}
