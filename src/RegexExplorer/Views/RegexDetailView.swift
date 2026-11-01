// Copyright © 2026 Robert Hedin

import AppKit
import SwiftUI

/// Edits one saved regex: its pattern, options and test text, with live, read-only results.
struct RegexDetailView: View {
    @Binding var regex: SavedRegex
    @State private var patternFocusRequest = 0
    /// The most recent finished evaluation, with the input it was made from.
    @State private var evaluated: EvaluatedInput?
    /// Whether the current input has taken long enough to evaluate that the user should know.
    @State private var isSlow = false

    /// Replace and Filter need every match to be correct; only the match list is capped.
    private var input: EvaluationInput {
        EvaluationInput(
            pattern: regex.pattern,
            options: regex.options,
            text: regex.sampleText,
            eachLine: regex.mode == .filter,
            matchLimit: regex.mode == .match ? RegexEvaluator.defaultMatchLimit : .max
        )
    }

    /// The evaluation to show results from, fitted to the current mode while the next one runs.
    /// Match mode's capped result would give a wrong Replace or Filter result, so those wait for
    /// the full evaluation; a full result is capped for Match mode, to keep highlighting quick.
    private var shownEvaluation: EvaluatedInput? {
        guard let evaluated else { return nil }
        // Matches of the whole text aren't Filter mode's, nor the other way round.
        guard evaluated.input.eachLine == (regex.mode == .filter) else { return nil }
        guard case .matches(let matches, let truncated) = evaluated.evaluation else { return evaluated }
        if regex.mode != .match {
            return truncated ? nil : evaluated
        }
        let limit = RegexEvaluator.defaultMatchLimit
        guard matches.count > limit else { return evaluated }
        return EvaluatedInput(
            input: evaluated.input,
            evaluation: .matches(Array(matches.prefix(limit)), truncated: true)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                PatternField(
                    pattern: $regex.pattern,
                    allowsExtendedSyntax: regex.options.allowsExtendedSyntax,
                    evaluation: evaluated?.evaluation,
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

            ResultsView(
                regex: $regex,
                evaluated: shownEvaluation.map { (text: $0.input.text, evaluation: $0.evaluation) },
                isSlow: isSlow
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        // Matching runs in the background so a slow pattern can't freeze the window. Until it
        // finishes, the previous result stays, shown with the text it was made from.
        .task(id: input) {
            let input = input
            isSlow = false
            let slowTimer = Task {
                try await Task.sleep(for: .milliseconds(300))
                isSlow = true
            }
            defer { slowTimer.cancel() }
            guard let evaluation = await RegexEvaluator.evaluateInBackground(
                pattern: input.pattern,
                options: input.options,
                in: input.text,
                eachLine: input.eachLine,
                matchLimit: input.matchLimit
            ) else { return }
            evaluated = EvaluatedInput(input: input, evaluation: evaluation)
            isSlow = false
        }
        .focusedSceneValue(\.editorActions, EditorActions(
            mode: regex.mode,
            setMode: { regex.mode = $0 },
            focusPattern: { patternFocusRequest += 1 }
        ))
    }
}

/// Everything that decides a regex's matches.
private struct EvaluationInput: Equatable {
    let pattern: String
    let options: RegexOptions
    let text: String
    /// Filter mode matches each line on its own, like the code it exports.
    let eachLine: Bool
    let matchLimit: Int
}

private struct EvaluatedInput {
    let input: EvaluationInput
    let evaluation: RegexEvaluation
}

/// The pattern field, coloured by syntax, with an inline message when the pattern doesn't compile.
private struct PatternField: View {
    @Binding var pattern: String
    let allowsExtendedSyntax: Bool
    /// `nil` while the current pattern hasn't been evaluated yet.
    let evaluation: RegexEvaluation?
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
