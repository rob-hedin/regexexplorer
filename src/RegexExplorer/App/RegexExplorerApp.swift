import SwiftUI

@main
struct RegexExplorerApp: App {
    @State private var library = Self.makeLibrary()

    /// The user's library, or a throwaway one when the app is only hosting unit tests,
    /// so test runs never read, seed or change the real file.
    private static func makeLibrary() -> RegexLibrary {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            let fileURL = FileManager.default.temporaryDirectory
                .appending(path: "RegexExplorerTestHost-\(UUID().uuidString)", directoryHint: .isDirectory)
                .appending(path: "regexes.json")
            return RegexLibrary(store: RegexLibraryStore(fileURL: fileURL))
        }
        return RegexLibrary(store: .standard(), starterRegexes: StarterRegexes.make())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
        }
        .defaultSize(width: 1200, height: 780)
        .commands {
            RegexCommands()
        }

        Window("Regex Cheat Sheet", id: CheatSheetView.windowID) {
            CheatSheetView()
        }
        .defaultSize(width: 560, height: 780)
    }
}
