// Copyright © 2026 Robert Hedin
// All Rights Reserved.

import Foundation

/// Common regexes the library starts with on first launch, so there is something to explore.
///
/// Each pattern is anchored with `^` and `$`, so the sample text puts one candidate per
/// line and turns on "^ $ match each line": the lines that match are valid, the rest are not.
enum StarterRegexes {
    static func make() -> [SavedRegex] {
        let perLine = RegexOptions(anchorsMatchLineEndings: true)
        func regex(_ name: String, _ pattern: String, _ lines: [String]) -> SavedRegex {
            SavedRegex(name: name, pattern: pattern, sampleText: lines.joined(separator: "\n"), options: perLine)
        }

        return [
            regex("Email Address", #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#, [
                "jane.doe@example.com",
                "support+tickets@mail.example.org",
                "not an email",
                "missing@tld",
                "@example.com",
            ]),
            regex("User Name", #"^[a-zA-Z0-9_-]{3,16}$"#, [
                "jane_doe",
                "user-42",
                "ab",
                "this_name_is_far_too_long",
                "bad name",
            ]),
            regex("Strong Password", #"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$"#, [
                "Passw0rd!",
                "S3cure&Strong",
                "password",
                "PASSWORD1!",
                "Short1!",
            ]),
            regex("IPv4 Address", #"^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"#, [
                "192.168.1.1",
                "10.0.0.255",
                "256.1.1.1",
                "192.168.1",
                "1.2.3.4.5",
            ]),
            regex("Secure URL", #"^https:\/\/[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#, [
                "https://www.swift.org/documentation",
                "https://example.com",
                "http://example.com",
                "ftp://files.example.com",
            ]),
            regex("Positive/Negative Integer", #"^-?\d+$"#, [
                "42",
                "-17",
                "0",
                "3.14",
                "12a",
            ]),
            regex("Decimal/Float", #"^-?\d*\.\d+$"#, [
                "3.14",
                "-0.5",
                ".75",
                "42",
                "1.2.3",
            ]),
            regex("Phone Number (Global)", #"^\+?[1-9]\d{1,14}$"#, [
                "+14155552671",
                "+442071838750",
                "4155552671",
                "+0123456789",
                "555-1234",
            ]),
            regex("US Zip Code", #"^\d{5}(-\d{4})?$"#, [
                "90210",
                "10001-1234",
                "1234",
                "123456",
                "90210-12",
            ]),
        ]
    }
}
