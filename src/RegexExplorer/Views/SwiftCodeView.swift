import AppKit
import SwiftUI

/// A sheet showing Swift code that does what the editor shows for a regex.
struct SwiftCodeView: View {
    let regex: SavedRegex
    @Environment(\.dismiss) private var dismiss
    @AppStorage("swiftCodeLanguageMode") private var languageMode = SwiftLanguageMode.swift6

    var body: some View {
        let code = SwiftCodeGenerator.code(for: regex, languageMode: languageMode)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Swift Code for \(regex.name)")
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
            .accessibilityLabel("Swift code")
            HStack {
                Button("Copy", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                }
                Picker("Language mode", selection: $languageMode) {
                    ForEach(SwiftLanguageMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .help("Swift 6 uses /…/ regex literals; Swift 5 uses #/…/#, which works in both")
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 560, idealWidth: 640, minHeight: 360, idealHeight: 440)
    }
}
