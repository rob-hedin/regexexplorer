// Copyright © 2026 Robert Hedin
// All Rights Reserved.

import Foundation

/// A named, reusable regular expression, together with the sample text it is
/// tried against and the options it is compiled with.
struct SavedRegex: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var pattern: String
    var sampleText: String
    var options: RegexOptions
    /// Which kind of result the editor shows.
    var mode: ExplorerMode
    /// The replacement template used in Replace mode, such as `<${name}>`.
    var replacement: String
    /// In Filter mode, keep the lines without a match instead of those with one.
    var invertsFilter: Bool
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        pattern: String = "",
        sampleText: String = "",
        options: RegexOptions = RegexOptions(),
        mode: ExplorerMode = .match,
        replacement: String = "",
        invertsFilter: Bool = false,
        createdAt: Date = .now,
        modifiedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.sampleText = sampleText
        self.options = options
        self.mode = mode
        self.replacement = replacement
        self.invertsFilter = invertsFilter
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt ?? createdAt
    }

    // Decoding tolerates missing fields so that files written by older
    // versions of the app keep loading as the model grows.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        pattern = try container.decodeIfPresent(String.self, forKey: .pattern) ?? ""
        sampleText = try container.decodeIfPresent(String.self, forKey: .sampleText) ?? ""
        options = try container.decodeIfPresent(RegexOptions.self, forKey: .options) ?? RegexOptions()
        // An unknown mode, perhaps from a newer version, falls back to Match rather than failing the whole file.
        mode = try container.decodeIfPresent(String.self, forKey: .mode).flatMap(ExplorerMode.init(rawValue:)) ?? .match
        replacement = try container.decodeIfPresent(String.self, forKey: .replacement) ?? ""
        invertsFilter = try container.decodeIfPresent(Bool.self, forKey: .invertsFilter) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? createdAt
    }
}

/// What the editor does with a regex's matches.
enum ExplorerMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// List the matches and their capture groups.
    case match
    /// Replace each match using a template.
    case replace
    /// Keep only the lines that contain a match (or only those that don't).
    case filter

    var id: Self { self }

    var title: String {
        switch self {
        case .match: "Match"
        case .replace: "Replace"
        case .filter: "Filter"
        }
    }
}
