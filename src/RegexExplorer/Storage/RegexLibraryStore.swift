// Copyright © 2026 Robert Hedin
// All Rights Reserved.

import Foundation

/// Reads and writes the saved regexes as a single JSON file.
struct RegexLibraryStore: Sendable {
    /// The on-disk format. `version` lets later releases migrate older files.
    struct File: Codable {
        static let currentVersion = 1

        var version: Int
        var regexes: [SavedRegex]
    }

    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// The store the app uses: `regexes.json` in the app's Application Support folder.
    static func standard() -> RegexLibraryStore {
        RegexLibraryStore(
            fileURL: URL.applicationSupportDirectory
                .appending(path: "RegexExplorer", directoryHint: .isDirectory)
                .appending(path: "regexes.json", directoryHint: .notDirectory)
        )
    }

    /// Whether anything has been saved yet.
    var fileExists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false))
    }

    /// Loads the saved regexes. A missing file means nothing has been saved yet.
    func load() throws -> [SavedRegex] {
        guard fileExists else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try Self.decoder.decode(File.self, from: data).regexes
    }

    func save(_ regexes: [SavedRegex]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try Self.encoder.encode(File(version: File.currentVersion, regexes: regexes))
        try data.write(to: fileURL, options: .atomic)
    }

    /// Moves an unreadable file aside so that new saves don't overwrite it.
    /// Returns where the file was moved to.
    @discardableResult
    func quarantineUnreadableFile() throws -> URL {
        let stamp = Int(Date.now.timeIntervalSince1970)
        let destination = fileURL.deletingLastPathComponent()
            .appending(path: "regexes.unreadable-\(stamp).json", directoryHint: .notDirectory)
        try FileManager.default.moveItem(at: fileURL, to: destination)
        return destination
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
