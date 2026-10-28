// Copyright © 2026 Robert Hedin
// All Rights Reserved.

/// A language the Code sheet can write code in.
///
/// The cases are in the order the menu lists them, which is alphabetical by title.
enum CodeLanguage: String, CaseIterable, Identifiable, Sendable {
    case csharp
    case cpp
    case go
    case java
    case javascript
    case kotlin
    case perl
    case php
    case python
    case r
    case ruby
    case rust
    case swift5
    case swift6

    static let `default` = CodeLanguage.swift6

    var id: Self { self }

    var title: String {
        switch self {
        case .csharp: "C#"
        case .cpp: "C++ (std::regex)"
        case .go: "Go"
        case .java: "Java"
        case .javascript: "JavaScript / TypeScript"
        case .kotlin: "Kotlin"
        case .perl: "Perl"
        case .php: "PHP"
        case .python: "Python"
        case .r: "R"
        case .ruby: "Ruby"
        case .rust: "Rust"
        case .swift5: "Swift 5"
        case .swift6: "Swift 6"
        }
    }

    /// A short note on what the code needs, shown under the code.
    var requirements: String {
        switch self {
        case .csharp: "C# 9 or later (.NET 5+), as a top-level program."
        case .cpp: "C++17 with the standard library's <regex>."
        case .go: "Go's standard regexp package (RE2 syntax)."
        case .java: "Java 16 or later, using java.util.regex."
        case .javascript: "Runs as JavaScript (ES2020+) or TypeScript."
        case .kotlin: "Kotlin, using kotlin.text.Regex rather than java.util.regex, so it also builds for Kotlin/Native."
        case .perl: "Perl 5.14 or later."
        case .php: "PHP 8 or later, using the preg functions."
        case .python: "Python 3, using the re module."
        case .r: "R 4.1 or later, using base R with perl = TRUE."
        case .ruby: "Ruby 2.4 or later."
        case .rust: "Rust with the regex crate (add regex = \"1\" to Cargo.toml)."
        case .swift5: "Swift 5.7 or later; #/…/# literals also compile in Swift 6."
        case .swift6: "Swift 6 language mode, which allows bare /…/ literals."
        }
    }
}
