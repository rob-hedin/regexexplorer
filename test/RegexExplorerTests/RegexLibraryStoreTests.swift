// Copyright © 2026 Robert Hedin

import Foundation
import Testing
@testable import RegexExplorer

final class RegexLibraryStoreTests {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: "RegexLibraryStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    var store: RegexLibraryStore {
        RegexLibraryStore(fileURL: directory.appending(path: "regexes.json"))
    }

    @Test func missingFileLoadsAsEmpty() throws {
        #expect(try store.load().isEmpty)
    }

    @Test func savedRegexesLoadBack() throws {
        // Whole seconds, because dates are stored as ISO 8601 without fractions.
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let regexes = [
            SavedRegex(name: "Domain", pattern: #"[a-z0-9-]+(\.[a-z0-9-]+)+"#, sampleText: "example.com",
                       options: RegexOptions(ignoresCase: true), mode: .replace, replacement: "<$0>",
                       invertsFilter: true, createdAt: date),
            SavedRegex(name: "Digits", pattern: #"\d+"#, createdAt: date),
        ]
        try store.save(regexes)
        #expect(try store.load() == regexes)
    }

    @Test func fileRecordsItsFormatVersion() throws {
        try store.save([])
        let file = try JSONDecoder().decode(RegexLibraryStore.File.self, from: Data(contentsOf: store.fileURL))
        #expect(file.version == RegexLibraryStore.File.currentVersion)
    }

    @Test func fileReferencesItsSchemaFirst() throws {
        try store.save([])
        let json = try String(contentsOf: store.fileURL, encoding: .utf8)
        #expect(json.hasPrefix("{\n  \"$schema\" : \"https://robhedin.com/schemas/regexexplorer-v20261028.json\","))
    }

    @Test func missingFieldsGetDefaults() throws {
        let json = #"{"version": 1, "regexes": [{"id": "6F9619FF-8B86-D011-B42D-00C04FC964FF", "name": "Old"}]}"#
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: store.fileURL)

        let regex = try #require(try store.load().first)
        #expect(regex.name == "Old")
        #expect(regex.pattern == "")
        #expect(regex.sampleText == "")
        #expect(regex.options == RegexOptions())
        #expect(regex.mode == .match)
        #expect(regex.replacement == "")
        #expect(!regex.invertsFilter)
    }

    @Test func unreadableFileIsMovedAside() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.fileURL)
        #expect(throws: (any Error).self) { try store.load() }

        let moved = try store.quarantineUnreadableFile()
        #expect(FileManager.default.fileExists(atPath: moved.path(percentEncoded: false)))
        #expect(try store.load().isEmpty)
    }
}
