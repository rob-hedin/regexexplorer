// Copyright © 2026 Robert Hedin

import AppKit
import SwiftUI

/// A single-line text field that colours the regex syntax as you type.
///
/// SwiftUI's TextField can't style its text while editing, so this wraps an NSTextField
/// and colours the field editor's text directly. Only the colours change, never the text,
/// so typing and undo behave as in any other field.
struct PatternTextField: NSViewRepresentable {
    @Binding var pattern: String
    var allowsExtendedSyntax: Bool
    /// Changes whenever something asks for the field to become focused, such as Edit Pattern.
    var focusRequest: Int

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.font = Self.font
        field.placeholderString = "Type a regular expression"
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.usesSingleLineMode = true
        field.lineBreakMode = .byClipping
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.allowsEditingTextAttributes = false
        field.setAccessibilityLabel("Pattern")
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.attributedStringValue = Self.highlighted(pattern, allowsExtendedSyntax: allowsExtendedSyntax)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self

        if let editor = field.currentEditor() as? NSTextView {
            if editor.string != pattern { editor.string = pattern }
            Self.color(editor, allowsExtendedSyntax: allowsExtendedSyntax)
        } else {
            field.attributedStringValue = Self.highlighted(pattern, allowsExtendedSyntax: allowsExtendedSyntax)
        }

        if context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            DispatchQueue.main.async { field.window?.makeFirstResponder(field) }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PatternTextField
        var lastFocusRequest: Int

        init(parent: PatternTextField) {
            self.parent = parent
            self.lastFocusRequest = parent.focusRequest
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            if let editor = notification.userInfo?["NSFieldEditor"] as? NSTextView {
                // A pattern needs exactly the characters typed, as the SwiftUI field's autocorrectionDisabled() gave.
                editor.isAutomaticSpellingCorrectionEnabled = false
                editor.isAutomaticTextReplacementEnabled = false
                editor.isAutomaticQuoteSubstitutionEnabled = false
                editor.isAutomaticDashSubstitutionEnabled = false
                PatternTextField.color(editor, allowsExtendedSyntax: parent.allowsExtendedSyntax)
            }
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            if let editor = notification.userInfo?["NSFieldEditor"] as? NSTextView {
                PatternTextField.color(editor, allowsExtendedSyntax: parent.allowsExtendedSyntax)
            }
            parent.pattern = field.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            // The field shows plain text once editing ends, so colour it again.
            field.attributedStringValue = PatternTextField.highlighted(
                field.stringValue,
                allowsExtendedSyntax: parent.allowsExtendedSyntax
            )
        }
    }

    // MARK: Colouring

    private static let font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)

    /// A capture group's parentheses take its colour in the results, so the other kinds
    /// use colours that the groups don't.
    static func color(for kind: RegexSyntaxKind) -> NSColor {
        switch kind {
        case .escape: .systemBrown
        case .characterClass: .systemGreen
        case .group(let number?): NSColor(MatchPresentation.color(forGroup: number))
        case .group(nil): .secondaryLabelColor
        case .quantifier: .systemRed
        case .anchor, .alternation: .systemIndigo
        case .comment: .tertiaryLabelColor
        }
    }

    /// Each token's colour and its range in the pattern's UTF-16 text, as AppKit counts it.
    static func colorRuns(in pattern: String, allowsExtendedSyntax: Bool) -> [(NSColor, NSRange)] {
        let tokens = RegexSyntaxHighlighter.tokens(in: pattern, allowsExtendedSyntax: allowsExtendedSyntax)
        guard !tokens.isEmpty else { return [] }
        // The UTF-16 offset at which each character starts, plus the end.
        var utf16Offsets: [Int] = []
        utf16Offsets.reserveCapacity(pattern.count + 1)
        var offset = 0
        for character in pattern {
            utf16Offsets.append(offset)
            offset += character.utf16.count
        }
        utf16Offsets.append(offset)
        return tokens.map { token in
            let start = utf16Offsets[token.range.lowerBound]
            let end = utf16Offsets[token.range.upperBound]
            return (color(for: token.kind), NSRange(location: start, length: end - start))
        }
    }

    static func highlighted(_ pattern: String, allowsExtendedSyntax: Bool) -> NSAttributedString {
        let text = NSMutableAttributedString(
            string: pattern,
            attributes: [.font: font, .foregroundColor: NSColor.labelColor]
        )
        for (color, range) in colorRuns(in: pattern, allowsExtendedSyntax: allowsExtendedSyntax) {
            text.addAttribute(.foregroundColor, value: color, range: range)
        }
        return text
    }

    /// Recolours the field editor's text in place, keeping the selection and undo history.
    static func color(_ editor: NSTextView, allowsExtendedSyntax: Bool) {
        guard let storage = editor.textStorage else { return }
        let whole = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: whole)
        for (color, range) in colorRuns(in: editor.string, allowsExtendedSyntax: allowsExtendedSyntax)
        where NSMaxRange(range) <= storage.length {
            storage.addAttribute(.foregroundColor, value: color, range: range)
        }
        storage.endEditing()
        // Typed characters start plain; the next pass colours them.
        editor.typingAttributes[.foregroundColor] = NSColor.labelColor
    }
}
