import Foundation

/// A named, reusable regular expression, together with the sample text it is
/// tried against and the options it is compiled with.
struct SavedRegex: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var pattern: String
    var sampleText: String
    var options: RegexOptions
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        pattern: String = "",
        sampleText: String = "",
        options: RegexOptions = RegexOptions(),
        createdAt: Date = .now,
        modifiedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.sampleText = sampleText
        self.options = options
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
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? createdAt
    }
}
