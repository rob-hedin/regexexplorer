import Foundation
import Observation

/// The user's collection of saved regexes. Every change is written to the store.
@MainActor
@Observable
final class RegexLibrary {
    private(set) var regexes: [SavedRegex] = []
    /// A description of the last load or save problem, for the UI to show.
    private(set) var lastError: String?

    @ObservationIgnored private let store: RegexLibraryStore

    init(store: RegexLibraryStore) {
        self.store = store
        load()
    }

    func regex(withID id: SavedRegex.ID) -> SavedRegex? {
        regexes.first { $0.id == id }
    }

    /// Adds a new, empty regex with a unique name and returns it.
    @discardableResult
    func add(name: String = "Untitled") -> SavedRegex {
        let regex = SavedRegex(name: uniqueName(startingWith: name))
        regexes.append(regex)
        persist()
        return regex
    }

    /// Replaces the stored regex that has the same ID.
    func update(_ regex: SavedRegex) {
        guard let index = regexes.firstIndex(where: { $0.id == regex.id }),
              regexes[index] != regex else { return }
        var updated = regex
        updated.modifiedAt = .now
        regexes[index] = updated
        persist()
    }

    func delete(ids: Set<SavedRegex.ID>) {
        regexes.removeAll { ids.contains($0.id) }
        persist()
    }

    func dismissError() {
        lastError = nil
    }

    /// Returns `base`, or `base` followed by the lowest number that isn't already in use.
    func uniqueName(startingWith base: String) -> String {
        let existing = Set(regexes.map(\.name))
        guard existing.contains(base) else { return base }
        var number = 2
        while existing.contains("\(base) \(number)") {
            number += 1
        }
        return "\(base) \(number)"
    }

    private func load() {
        do {
            regexes = try store.load()
        } catch {
            // Keep the unreadable file for the user rather than overwriting it on the next save.
            let moved = try? store.quarantineUnreadableFile()
            lastError = "Your saved regexes couldn't be read"
                + (moved.map { ", so the file was moved to \($0.lastPathComponent)" } ?? "")
                + ". \(error.localizedDescription)"
        }
    }

    private func persist() {
        do {
            try store.save(regexes)
        } catch {
            lastError = "Your regexes couldn't be saved. \(error.localizedDescription)"
        }
    }
}
