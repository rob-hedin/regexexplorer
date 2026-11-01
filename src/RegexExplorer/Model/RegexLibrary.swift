// Copyright © 2026 Robert Hedin

import Foundation
import Observation

/// The user's collection of saved regexes. Every change is written to the store: edits shortly
/// after typing pauses, and additions and deletions straight away.
@MainActor
@Observable
final class RegexLibrary {
    private(set) var regexes: [SavedRegex] = []
    /// A description of the last load or save problem, for the UI to show.
    private(set) var lastError: String?

    @ObservationIgnored private let store: RegexLibraryStore
    /// Set when an unreadable file couldn't be moved aside, or the file is from a newer
    /// release. Saving would then replace it, so changes stay in memory and the file is kept.
    @ObservationIgnored private var savingIsBlocked = false
    /// A save waiting for edits to pause, so typing doesn't rewrite the file on every keystroke.
    @ObservationIgnored private var pendingSave: Task<Void, Never>?

    /// How long edits must pause before they're saved.
    static let saveDelay = Duration.milliseconds(500)

    /// Loads the library from `store`. If nothing has been saved yet, the library starts
    /// with `starterRegexes` and saves them; an existing file, even an empty one, is never added to.
    init(store: RegexLibraryStore, starterRegexes: [SavedRegex] = []) {
        self.store = store
        if !starterRegexes.isEmpty, !store.fileExists {
            regexes = starterRegexes
            persist()
        } else {
            load()
        }
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
        scheduleSave()
    }

    func delete(ids: Set<SavedRegex.ID>) {
        regexes.removeAll { ids.contains($0.id) }
        persist()
    }

    /// Writes any edits that are waiting to be saved, such as when the app quits.
    func saveNow() {
        guard pendingSave != nil else { return }
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
        } catch let error as RegexLibraryStore.NewerFormatError {
            // The file is fine, just newer: leave it where it is and don't overwrite it.
            savingIsBlocked = true
            lastError = "Your saved regexes were saved by a newer version of RegEx Explorer, "
                + "so they can't be opened and changes won't be saved. \(error.localizedDescription)"
        } catch {
            // Keep the unreadable file for the user rather than overwriting it on the next save.
            if let moved = try? store.quarantineUnreadableFile() {
                lastError = "Your saved regexes couldn't be read, so the file was moved to "
                    + "\(moved.lastPathComponent). \(error.localizedDescription)"
            } else {
                savingIsBlocked = true
                lastError = "Your saved regexes couldn't be read, and the file couldn't be moved aside, "
                    + "so changes won't be saved. Move or fix \(store.fileURL.path(percentEncoded: false)), then reopen the app. "
                    + error.localizedDescription
            }
        }
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            self?.persist()
        }
    }

    private func persist() {
        pendingSave?.cancel()
        pendingSave = nil
        guard !savingIsBlocked else { return }
        do {
            try store.save(regexes)
        } catch {
            lastError = "Your regexes couldn't be saved. \(error.localizedDescription)"
        }
    }
}
