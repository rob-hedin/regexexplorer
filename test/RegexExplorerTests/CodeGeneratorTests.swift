// Copyright © 2026 Robert Hedin

import Testing
@testable import RegexExplorer

struct CodeGeneratorTests {
    private func regex(
        _ pattern: String,
        mode: ExplorerMode = .match,
        replacement: String = "",
        options: RegexOptions = RegexOptions()
    ) -> SavedRegex {
        SavedRegex(name: "Test", pattern: pattern, sampleText: "abc", options: options, mode: mode, replacement: replacement)
    }

    private func code(_ language: CodeLanguage, _ regex: SavedRegex) -> String {
        CodeGenerator.code(for: regex, language: language)
    }

    @Test func languagesAreListedAlphabetically() {
        let titles = CodeLanguage.allCases.map { $0.title.lowercased() }
        #expect(titles == titles.sorted())
        #expect(CodeLanguage.allCases.count == 14)
        #expect(CodeLanguage.default == .swift6)
    }

    @Test func swiftLanguagesMatchTheSwiftGenerator() {
        let saved = regex("a(b)c")
        #expect(code(.swift6, saved) == SwiftCodeGenerator.code(for: saved, languageMode: .swift6))
        #expect(code(.swift5, saved) == SwiftCodeGenerator.code(for: saved, languageMode: .swift5))
    }

    @Test(arguments: CodeLanguage.allCases)
    func everyLanguageWritesEveryMode(language: CodeLanguage) {
        for mode in ExplorerMode.allCases {
            let generated = code(language, regex(#"(?<word>\w+)-(\d+)"#, mode: mode, replacement: "${word}:$2"))
            #expect(generated.contains("abc"), "\(language) \(mode)")
            #expect(generated.hasSuffix("\n"))
        }
    }

    @Test func pythonUsesItsNamedGroupSyntax() {
        let generated = code(.python, regex(#"(?<year>\d{4})\k<year>"#))
        #expect(generated.contains(#"r"(?P<year>\d{4})(?P=year)""#))
    }

    @Test func pythonReplacementUsesGroupReferences() {
        let generated = code(.python, regex(#"(\w+) (?<last>\w+)"#, mode: .replace, replacement: #"${last} $1 \"#))
        #expect(generated.contains(#"pattern.sub(r"\g<last> \g<1> \\", text)"#))
    }

    @Test func javaScriptEscapesSlashesAndAddsFlags() {
        let generated = code(.javascript, regex("a/b", options: RegexOptions(ignoresCase: true)))
        #expect(generated.contains(#"const regex = /a\/b/gi;"#))
    }

    @Test func javaScriptFilterRegexIsNotGlobal() {
        // A global regex's test() remembers where it stopped, which would skip lines.
        #expect(code(.javascript, regex("a", mode: .filter)).contains("const regex = /a/;"))
    }

    @Test func javaScriptKeepsADigitAfterAGroupLiteral() {
        let generated = code(.javascript, regex("(a)(b)", mode: .replace, replacement: "$12$$"))
        #expect(generated.contains(#"text.replace(regex, "$012$$")"#))
    }

    @Test func javaEscapesADigitAfterAGroup() {
        let generated = code(.java, regex("(a)(b)", mode: .replace, replacement: "$12$$"))
        #expect(generated.contains(#"replaceAll("$1\\2\\$")"#))
    }

    @Test func cSharpNumbersUnnamedGroupsFirst() {
        let generated = code(.csharp, regex(#"(?<y>a)(b)"#))
        #expect(generated.contains(#"match.Groups["y"].Value); // Group 1 (y)"#))
        #expect(generated.contains("match.Groups[1].Value); // Group 2"))
    }

    @Test func goAndRustWarnAboutLookarounds() {
        let saved = regex(#"(?<=\$)\d+"#)
        #expect(code(.go, saved).contains("doesn't support lookarounds"))
        #expect(code(.rust, saved).contains("doesn't support lookarounds"))
        #expect(!code(.python, saved).contains("Note:"))
    }

    @Test func cppDropsNamesAndRewritesTheDot() {
        let generated = code(.cpp, regex(#"(?<x>a.)\k<x>"#, options: RegexOptions(dotMatchesNewlines: true)))
        #expect(generated.contains(#"R"((a[\s\S])\1)""#))
    }

    @Test func cppWarnsAboutTextOutsideASCII() {
        #expect(!code(.cpp, regex("w.rld")).contains("Note:"))
        #expect(code(.cpp, regex("wörld")).contains("Note: std::regex reads UTF-8 text a byte at a time"))
    }

    @Test func rWrapsThePatternToReplaceWithTheWholeMatch() {
        let generated = code(.r, regex(#"(\w)\d"#, mode: .replace, replacement: "<$0|$1>"))
        #expect(generated.contains(#"pattern <- r"(((\w)\d))""#))
        #expect(generated.contains(#"gsub(pattern, "<\\1|\\2>", text, perl = TRUE)"#))
        #expect(!generated.contains("Note:"))
        #expect(code(.r, regex(#"(a)\1"#, mode: .replace, replacement: "$0")).contains("Note:"))
    }

    @Test func extendedSyntaxIsStrippedWhereUnsupported() {
        let saved = regex("a b # note\n[ ]c", options: RegexOptions(allowsExtendedSyntax: true))
        #expect(code(.javascript, saved).contains("const regex = /ab[ ]c/g;"))
        #expect(code(.go, saved).contains("regexp.MustCompile(`ab[ ]c`)"))
    }

    @Test func rubyNamesUnnamedGroupsWhenThereAreNamedOnes() {
        let generated = code(.ruby, regex(#"(?<word>\w+)-(\d+)"#))
        #expect(generated.contains(#"(?<word>\w+)-(?<group2>\d+)"#))
        #expect(generated.contains("puts match[:group2] # Group 2"))
    }

    @Test func rubyAnchorsMatchTheWholeTextUnlessAskedNotTo() {
        #expect(code(.ruby, regex(#"^a$"#)).contains(#"regex = /\Aa\Z/"#))
        #expect(code(.ruby, regex(#"^a$"#, options: RegexOptions(anchorsMatchLineEndings: true))).contains("regex = /^a$/"))
    }

    @Test func perlAndPHPQuoteThePatternSafely() {
        let saved = regex(#"it's\d"#)
        #expect(code(.perl, saved).contains(#"qr'it\'s\d'"#))
        #expect(code(.php, saved).contains(#"'/it\'s\\d/u'"#))
    }

    @Test func rawStringsGetDelimitersWhenNeeded() {
        #expect(RustCodeGenerator.rawLiteral(#"a"b"#) == ##"r#"a"b"#"##)
        #expect(CppCodeGenerator.rawLiteral(#"(a)""#) == #"R"x((a)")x""#)
        #expect(RCodeGenerator.rawLiteral(#"(a)""#) == #"r"-((a)")-""#)
    }

    @Test func featuresAreFound() {
        let features = PatternFeatures(pattern: #"(?=a)(?<!b)(?>c)d++\1\p{L}(?i)\A"#, allowsExtendedSyntax: false)
        #expect(features == [.lookahead, .lookbehind, .atomicGroup, .possessiveQuantifier, .backreference,
                             .unicodeProperty, .inlineFlags, .absoluteAnchor])
        #expect(PatternFeatures(pattern: #"[(?=)]\(?=x"#, allowsExtendedSyntax: false).isEmpty)
    }

    @Test func rewriteLeavesClassesAndEscapesAlone() {
        let rewrite = PatternRewrite(namedGroups: .python, dotMatchesNewlines: true, anchorsMatchWholeText: true)
        #expect(rewrite.apply(to: #"[.^$(?<n>)]\.\^(?'n'x)"#, groups: ["n"], allowsExtendedSyntax: false)
            == #"[.^$(?<n>)]\.\^(?P<n>x)"#)
    }
}
