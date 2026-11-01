// Copyright © 2026 Robert Hedin

import AppKit
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
        let library = RegexLibrary(store: .standard(), starterRegexes: StarterRegexes.make())
        // Edits are saved after a short pause; don't lose the last ones when the app quits.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { library.saveNow() }
        }
        return library
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
        }
        .defaultSize(width: 1200, height: 780)
        .commands {
            SidebarCommands()
            RegexCommands()
        }

        Window("Regex Cheat Sheet", id: CheatSheetView.windowID) {
            CheatSheetView()
        }
        .defaultSize(width: 560, height: 780)
    }
}
