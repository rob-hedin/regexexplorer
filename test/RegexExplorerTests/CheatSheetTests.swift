import Testing
@testable import RegexExplorer

struct CheatSheetTests {
    @Test func emptySearchShowsEverything() {
        #expect(CheatSheet.sections(matching: "  ") == CheatSheet.sections)
    }

    @Test func searchKeepsMatchingEntriesOnly() {
        let sections = CheatSheet.sections(matching: "newline")
        #expect(sections.map(\.title) == ["Characters", "Lookahead and Flags"])
        #expect(sections.flatMap(\.entries).map(\.token) == [".", #"\t  \n"#, "(?s)"])
    }

    @Test func searchMatchingASectionTitleKeepsTheWholeSection() {
        let sections = CheatSheet.sections(matching: "quantifiers")
        #expect(sections.map(\.title) == ["Quantifiers"])
        #expect(sections.first?.entries.count == 6)
    }

    @Test func searchWithNoMatchesIsEmpty() {
        #expect(CheatSheet.sections(matching: "zzz").isEmpty)
    }

    /// Every token that is a complete pattern on its own should compile.
    @Test(arguments: ["(?<name>abc)", "(?:abc)", "(?=abc)", "(?!abc)", #"\1"#, #"\A"#, #"\z"#, "*?"])
    func cheatSheetSyntaxIsSupported(token: String) throws {
        let pattern = switch token {
        case #"\1"#: #"(a)\1"#
        case "*?": "a*?"
        default: token
        }
        _ = try Regex(pattern)
    }
}
