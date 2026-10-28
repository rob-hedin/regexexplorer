// Copyright © 2026 Robert Hedin

import Foundation

/// Reads and writes the saved regexes as a single JSON file.
struct RegexLibraryStore: Sendable {
    /// The on-disk format. `version` lets later releases migrate older files, and
    /// `$schema` names the JSON schema that describes it (see docs/storage-format.md).
    struct File: Codable {
        static let currentVersion = 1
        /// Where the schema for the current format is published. Its copy is in schemas/.
        static let schemaURL = "https://robhedin.com/schemas/regexexplorer-v20261028.json"

        /// `nil` in files written before the schema existed.
        var schema: String?
        var version: Int
        var regexes: [SavedRegex]

        enum CodingKeys: String, CodingKey {
            case schema = "$schema"
            case version
            case regexes
        }
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
        let data = try Self.encoder.encode(File(schema: File.schemaURL, version: File.currentVersion, regexes: regexes))
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
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
