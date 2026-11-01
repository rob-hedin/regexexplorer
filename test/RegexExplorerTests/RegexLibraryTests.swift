// Copyright © 2026 Robert Hedin

import Foundation
import Testing
@testable import RegexExplorer

@MainActor
final class RegexLibraryTests {
    let store = RegexLibraryStore(
        fileURL: FileManager.default.temporaryDirectory
            .appending(path: "RegexLibraryTests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: "regexes.json")
    )

    deinit {
        try? FileManager.default.removeItem(at: store.fileURL.deletingLastPathComponent())
    }

    @Test func addedRegexesGetUniqueNames() {
        let library = RegexLibrary(store: store)
        library.add()
        library.add()
        library.add()
        #expect(library.regexes.map(\.name) == ["Untitled", "Untitled 2", "Untitled 3"])
    }

    @Test func changesAreSavedToTheStore() throws {
        let library = RegexLibrary(store: store)
        var regex = library.add(name: "Domain")
        regex.pattern = #"\w+\.com"#
        library.update(regex)
        library.saveNow()

        let reloaded = RegexLibrary(store: store)
        #expect(reloaded.regexes.map(\.name) == ["Domain"])
        #expect(reloaded.regexes.first?.pattern == #"\w+\.com"#)
    }

    @Test func updateRecordsTheModificationTime() throws {
        let library = RegexLibrary(store: store)
        var regex = library.add()
        let before = regex.modifiedAt
        regex.pattern = "a"
        library.update(regex)
        #expect(try #require(library.regex(withID: regex.id)).modifiedAt >= before)
    }

    @Test func deleteRemovesRegexes() {
        let library = RegexLibrary(store: store)
        let first = library.add()
        library.add()
        library.delete(ids: [first.id])

        #expect(library.regexes.map(\.name) == ["Untitled 2"])
        #expect(RegexLibrary(store: store).regexes.count == 1)
    }

    @Test func unreadableFileIsKeptAndReported() throws {
        try FileManager.default.createDirectory(
            at: store.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(to: store.fileURL)

        let library = RegexLibrary(store: store)
        #expect(library.regexes.isEmpty)
        #expect(library.lastError != nil)

        let siblings = try FileManager.default.contentsOfDirectory(atPath: store.fileURL.deletingLastPathComponent().path(percentEncoded: false))
        #expect(siblings.contains { $0.hasPrefix("regexes.unreadable-") })
    }

    @Test func unreadableFileThatCantBeMovedIsNeverOverwritten() throws {
        let folder = store.fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.fileURL)
        // A folder that can't be written to stops the file being moved aside.
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path(percentEncoded: false))
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path(percentEncoded: false))
        }

        let library = RegexLibrary(store: store)
        let loadError = try #require(library.lastError)
        // Let saving succeed again, as it might if the folder's permissions changed.
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path(percentEncoded: false))
        library.add()

        #expect(try Data(contentsOf: store.fileURL) == Data("not json".utf8))
        #expect(library.regexes.count == 1)
        #expect(library.lastError == loadError)
    }

    @Test func startersAreSavedWhenNothingHasBeenSaved() {
        let starters = [SavedRegex(name: "Zip", pattern: #"^\d{5}$"#), SavedRegex(name: "Integer", pattern: #"^-?\d+$"#)]
        let library = RegexLibrary(store: store, starterRegexes: starters)
        #expect(library.regexes == starters)
        // Saved dates lose their fractional seconds, so compare what was saved by name and pattern.
        let reloaded = RegexLibrary(store: store).regexes
        #expect(reloaded.map(\.name) == ["Zip", "Integer"])
        #expect(reloaded.map(\.pattern) == starters.map(\.pattern))
    }

    @Test func startersAreNotAddedWhenTheUserDeletedEverything() throws {
        try store.save([])
        let library = RegexLibrary(store: store, starterRegexes: [SavedRegex(name: "Zip")])
        #expect(library.regexes.isEmpty)
    }

    @Test func startersAreNotAddedWhenTheFileWasUnreadable() throws {
        try FileManager.default.createDirectory(
            at: store.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(to: store.fileURL)

        let library = RegexLibrary(store: store, starterRegexes: [SavedRegex(name: "Zip")])
        #expect(library.regexes.isEmpty)
        #expect(library.lastError != nil)
    }

    @Test func newerFormatIsLeftAlone() throws {
        try FileManager.default.createDirectory(at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let newer = Data(#"{"version": 99, "regexes": []}"#.utf8)
        try newer.write(to: store.fileURL)

        let library = RegexLibrary(store: store)
        #expect(library.lastError?.contains("newer version") == true)
        library.add()
        #expect(try Data(contentsOf: store.fileURL) == newer)
    }

    @Test func editsAreSavedAfterAPause() async throws {
        let library = RegexLibrary(store: store)
        var regex = library.add()
        regex.pattern = "a"
        library.update(regex)
        #expect(RegexLibrary(store: store).regexes.first?.pattern == "")

        try await Task.sleep(for: RegexLibrary.saveDelay + .milliseconds(300))
        #expect(RegexLibrary(store: store).regexes.first?.pattern == "a")
    }
}
