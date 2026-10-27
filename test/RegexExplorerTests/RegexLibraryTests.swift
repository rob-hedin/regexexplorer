import Foundation
import Testing
@testable import RegexExplorer

@MainActor
struct RegexLibraryTests {
    let store = RegexLibraryStore(
        fileURL: FileManager.default.temporaryDirectory
            .appending(path: "RegexLibraryTests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: "regexes.json")
    )

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
}
