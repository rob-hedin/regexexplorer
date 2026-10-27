import SwiftUI

@main
struct RegexExplorerApp: App {
    @State private var library = RegexLibrary(store: .standard())

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
        }
    }
}
