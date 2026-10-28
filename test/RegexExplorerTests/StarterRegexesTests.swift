// Copyright © 2026 Robert Hedin
// All Rights Reserved.

import Foundation
import Testing
@testable import RegexExplorer

struct StarterRegexesTests {
    /// The sample lines each starter regex should match, in order. Every other line shouldn't.
    static let expectedMatchingLines: [String: [String]] = [
        "Email Address": ["jane.doe@example.com", "support+tickets@mail.example.org"],
        "User Name": ["jane_doe", "user-42"],
        "Strong Password": ["Passw0rd!", "S3cure&Strong"],
        "IPv4 Address": ["192.168.1.1", "10.0.0.255"],
        "Secure URL": ["https://www.swift.org/documentation", "https://example.com"],
        "Positive/Negative Integer": ["42", "-17", "0"],
        "Decimal/Float": ["3.14", "-0.5", ".75"],
        "Phone Number (Global)": ["+14155552671", "+442071838750", "4155552671"],
        "US Zip Code": ["90210", "10001-1234"],
    ]

    @Test func namesAreUniqueAndAllCovered() {
        let names = StarterRegexes.make().map(\.name)
        #expect(Set(names).count == names.count)
        #expect(Set(names) == Set(Self.expectedMatchingLines.keys))
    }

    @Test(arguments: StarterRegexes.make())
    func sampleTextShowsWhichLinesMatch(regex: SavedRegex) throws {
        let evaluation = RegexEvaluator.evaluate(pattern: regex.pattern, options: regex.options, in: regex.sampleText)
        guard case .matches(let matches, _) = evaluation else {
            Issue.record("\(regex.name) didn't compile: \(evaluation)")
            return
        }
        let text = regex.sampleText
        let matchingLines = matches.map { String(text[text.lineRange(for: $0.range)]).trimmingCharacters(in: .newlines) }
        #expect(matchingLines == Self.expectedMatchingLines[regex.name])
    }
}
