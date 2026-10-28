// Copyright © 2026 Robert Hedin

import SwiftUI

/// The list of saved regexes, with search, add, rename and delete.
struct RegexSidebar: View {
    @Environment(RegexLibrary.self) private var library
    @Binding var selection: SavedRegex.ID?
    @State private var searchText = ""
    @State private var renamingID: SavedRegex.ID?

    private var visibleRegexes: [SavedRegex] {
        guard !searchText.isEmpty else { return library.regexes }
        return library.regexes.filter {
            $0.name.localizedStandardContains(searchText) || $0.pattern.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        List(selection: $selection) {
            Section("Saved Regexes") {
                ForEach(visibleRegexes) { regex in
                    RegexRow(
                        regex: regex,
                        isRenaming: renamingID == regex.id,
                        commitRename: { rename(regex, to: $0) }
                    )
                    .tag(regex.id)
                    .contextMenu {
                        Button("Rename") { renamingID = regex.id }
                        Divider()
                        Button("Delete", role: .destructive) { delete([regex.id]) }
                    }
                }
            }
        }
        .searchable(text: $searchText, placement: .sidebar)
        .focusedSceneValue(\.sidebarActions, SidebarActions(
            add: addRegex,
            renameSelected: selection.map { id in { renamingID = id } },
            deleteSelected: selection.map { id in { delete([id]) } }
        ))
        .onDeleteCommand {
            if let selection { delete([selection]) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 4) {
                    Button("New Regex", systemImage: "plus", action: addRegex)
                    Button("Delete Regex", systemImage: "minus") {
                        if let selection { delete([selection]) }
                    }
                    .disabled(selection == nil)
                    Spacer()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .padding(8)
            }
        }
    }

    private func addRegex() {
        let regex = library.add()
        searchText = ""
        selection = regex.id
        renamingID = regex.id
    }

    private func rename(_ regex: SavedRegex, to name: String) {
        renamingID = nil
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != regex.name else { return }
        var renamed = regex
        renamed.name = trimmed
        library.update(renamed)
    }

    /// Deletes the regexes and moves the selection to a neighbour of the first one removed.
    private func delete(_ ids: Set<SavedRegex.ID>) {
        let visible = visibleRegexes
        let firstIndex = visible.firstIndex { ids.contains($0.id) }
        library.delete(ids: ids)

        guard let selected = selection, ids.contains(selected) else { return }
        let remaining = visible.filter { !ids.contains($0.id) }
        if let firstIndex, !remaining.isEmpty {
            selection = remaining[min(firstIndex, remaining.count - 1)].id
        } else {
            selection = nil
        }
    }
}

private struct RegexRow: View {
    let regex: SavedRegex
    let isRenaming: Bool
    let commitRename: (String) -> Void

    @State private var draftName = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if isRenaming {
                TextField("Name", text: $draftName)
                    .focused($isNameFocused)
                    .onSubmit { commitRename(draftName) }
                    .onAppear {
                        draftName = regex.name
                        isNameFocused = true
                    }
                    .onChange(of: isNameFocused) { _, isFocused in
                        if !isFocused { commitRename(draftName) }
                    }
            } else {
                Text(regex.name)
                    .fontWeight(.semibold)
            }
            Text(regex.pattern.isEmpty ? "No pattern" : regex.pattern)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.vertical, 3)
    }
}
