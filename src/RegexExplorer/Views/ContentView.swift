import SwiftUI

/// A placeholder window used while the foundation is built.
/// The real split view replaces it in step 2, once the screen design is agreed.
struct ContentView: View {
    @Environment(RegexLibrary.self) private var library
    @State private var selection: SavedRegex.ID?

    var body: some View {
        NavigationSplitView {
            List(library.regexes, selection: $selection) { regex in
                Text(regex.name)
            }
            .toolbar {
                Button("New Regex", systemImage: "plus") {
                    selection = library.add().id
                }
            }
        } detail: {
            Text("The regex editor arrives in step 2.")
                .foregroundStyle(.secondary)
        }
    }
}
