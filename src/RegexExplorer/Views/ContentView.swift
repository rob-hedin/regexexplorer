import SwiftUI

/// The main window: saved regexes on the left, the selected one's editor on the right.
struct ContentView: View {
    @Environment(RegexLibrary.self) private var library
    @State private var selection: SavedRegex.ID?

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
        .navigationTitle(selection.flatMap { library.regex(withID: $0)?.name } ?? "RegEx Explorer")
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
