import SwiftUI

/// The main window: saved regexes on the left, the selected one's editor on the right.
struct ContentView: View {
    @Environment(RegexLibrary.self) private var library
    @Environment(\.openWindow) private var openWindow
    @State private var selection: SavedRegex.ID?
    @State private var isShowingCode = false

    private var selectedRegex: SavedRegex? {
        selection.flatMap { library.regex(withID: $0) }
    }

    /// Code can only be written for a pattern that compiles.
    private var canShowCode: Bool {
        guard let regex = selectedRegex, !regex.pattern.isEmpty else { return false }
        return (try? RegexEvaluator.makeRegex(pattern: regex.pattern, options: regex.options)) != nil
    }

    private var showCodeAction: CodeAction? {
        canShowCode ? CodeAction { isShowingCode = true } : nil
    }

    var body: some View {
        NavigationSplitView {
            RegexSidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
        } detail: {
            if let id = selection, let regex = binding(for: id) {
                RegexDetailView(regex: regex)
                    .id(id)
            } else {
                ContentUnavailableView(
                    "No Regex Selected",
                    systemImage: "text.magnifyingglass",
                    description: Text("Choose a regex from the list, or click + to create one.")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Code", systemImage: "chevron.left.forwardslash.chevron.right") {
                    isShowingCode = true
                }
                .labelStyle(.titleAndIcon)
                .disabled(!canShowCode)
                .help("Show code that uses this regex, in a language you choose")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Cheat Sheet", systemImage: "book.closed") {
                    openWindow(id: CheatSheetView.windowID)
                }
                .labelStyle(.titleAndIcon)
                .help("Open the regex cheat sheet")
            }
        }
        .focusedSceneValue(\.showCode, showCodeAction)
        .sheet(isPresented: $isShowingCode) {
            if let selectedRegex {
                CodeView(regex: selectedRegex)
            }
        }
        .navigationTitle(selectedRegex?.name ?? "RegEx Explorer")
        .frame(minWidth: 820, minHeight: 520)
        .alert(
            "Something Went Wrong",
            isPresented: Binding(get: { library.lastError != nil }, set: { if !$0 { library.dismissError() } }),
            presenting: library.lastError
        ) { _ in
            Button("OK") { library.dismissError() }
        } message: { message in
            Text(message)
        }
    }

    /// A binding that reads the regex from the library and writes edits back to it.
    private func binding(for id: SavedRegex.ID) -> Binding<SavedRegex>? {
        guard let regex = library.regex(withID: id) else { return nil }
        return Binding(
            get: { library.regex(withID: id) ?? regex },
            set: { library.update($0) }
        )
    }
}
