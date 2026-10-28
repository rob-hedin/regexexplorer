// Copyright © 2026 Robert Hedin

import AppKit
import SwiftUI

/// Edits one saved regex: its pattern, options and test text, with live, read-only results.
struct RegexDetailView: View {
    @Binding var regex: SavedRegex
    @State private var patternFocusRequest = 0

    var body: some View {
        // Replace and Filter need every match to be correct; only the match list is capped.
        let evaluation = RegexEvaluator.evaluate(
            pattern: regex.pattern,
            options: regex.options,
            in: regex.sampleText,
            matchLimit: regex.mode == .match ? RegexEvaluator.defaultMatchLimit : .max
        )

        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                PatternField(
                    pattern: $regex.pattern,
                    allowsExtendedSyntax: regex.options.allowsExtendedSyntax,
                    evaluation: evaluation,
                    focusRequest: patternFocusRequest
                )
                RegexOptionsBar(options: $regex.options)
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Test Text")
                TextEditor(text: $regex.sampleText)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(.background, in: .rect(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(.separator))
                    .frame(minHeight: 80, idealHeight: 110, maxHeight: 160)
                    .accessibilityLabel("Test text")
            }

            ResultsView(regex: $regex, evaluation: evaluation)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .focusedSceneValue(\.editorActions, EditorActions(
            mode: regex.mode,
            setMode: { regex.mode = $0 },
            focusPattern: { patternFocusRequest += 1 }
        ))
    }
}

/// The pattern field, coloured by syntax, with an inline message when the pattern doesn't compile.
private struct PatternField: View {
    @Binding var pattern: String
    let allowsExtendedSyntax: Bool
    let evaluation: RegexEvaluation
    let focusRequest: Int

    private var errorMessage: String? {
        if case .invalidPattern(let message) = evaluation { message } else { nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Pattern")
            HStack(spacing: 6) {
                PatternTextField(
                    pattern: $pattern,
                    allowsExtendedSyntax: allowsExtendedSyntax,
                    focusRequest: focusRequest
                )
                    .overlay {
                        if errorMessage != nil {
                            RoundedRectangle(cornerRadius: 6).stroke(.red, lineWidth: 1.5)
                        }
                    }
                Button("Copy Pattern", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(pattern, forType: .string)
                }
                .labelStyle(.iconOnly)
                .disabled(pattern.isEmpty)
                .help("Copy the pattern")
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
    }
}

/// A small uppercase heading above each part of the editor.
struct SectionLabel: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .textCase(.uppercase)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}
