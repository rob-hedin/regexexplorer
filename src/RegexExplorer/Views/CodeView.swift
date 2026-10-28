// Copyright © 2026 Robert Hedin

import AppKit
import SwiftUI

/// A sheet showing code, in a language you choose, that does what the editor shows for a regex.
struct CodeView: View {
    let regex: SavedRegex
    @Environment(\.dismiss) private var dismiss
    @AppStorage("codeLanguage") private var language = CodeLanguage.default

    var body: some View {
        let code = CodeGenerator.code(for: regex, language: language)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Code for \(regex.name)")
                    .font(.headline)
                Spacer()
                Text(regex.mode.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ScrollView([.horizontal, .vertical]) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(.quinary, in: .rect(cornerRadius: 7))
            .accessibilityLabel("\(language.title) code")
            Text(language.requirements)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Copy", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                }
                Picker("Language", selection: $language) {
                    ForEach(CodeLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
                .help("The language to write the code in")
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 600, idealWidth: 700, minHeight: 380, idealHeight: 480)
    }
}
