import SwiftUI

@main
struct RegexExplorerApp: App {
    @State private var library = RegexLibrary(store: .standard())

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
        }
        .defaultSize(width: 1200, height: 780)
    }
}
