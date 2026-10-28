// Copyright © 2026 Robert Hedin
// All Rights Reserved.

import SwiftUI

/// What the sidebar of the focused window can do, for the menu commands.
struct SidebarActions {
    var add: () -> Void
    /// `nil` when no regex is selected.
    var renameSelected: (() -> Void)?
    var deleteSelected: (() -> Void)?
}

/// What the editor of the focused window can do, for the menu commands.
struct EditorActions {
    var mode: ExplorerMode
    var setMode: (ExplorerMode) -> Void
    var focusPattern: () -> Void
}

/// Shows the code sheet for the focused window. Wrapped in a struct because
/// storing a bare closure in a focused value makes SwiftUI warn that it can't compare it.
struct CodeAction {
    var show: () -> Void
}

extension FocusedValues {
    @Entry var sidebarActions: SidebarActions?
    @Entry var editorActions: EditorActions?
    /// Shows the code sheet; `nil` when there's no valid pattern to write code for.
    @Entry var showCode: CodeAction?
}

/// The app's menu commands and keyboard shortcuts.
struct RegexCommands: Commands {
    @FocusedValue(\.sidebarActions) private var sidebar
    @FocusedValue(\.editorActions) private var editor
    @FocusedValue(\.showCode) private var showCode
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Regex") { sidebar?.add() }
                .keyboardShortcut("n")
                .disabled(sidebar == nil)
        }

        CommandMenu("Regex") {
            Button("Rename…") { sidebar?.renameSelected?() }
                .keyboardShortcut("r")
                .disabled(sidebar?.renameSelected == nil)
            // No ⌘⌫ shortcut: in a text field that deletes to the start of the line,
            // and the Delete key already deletes the selected regex in the sidebar.
            Button("Delete") { sidebar?.deleteSelected?() }
                .disabled(sidebar?.deleteSelected == nil)

            Divider()

            Button("Edit Pattern") { editor?.focusPattern() }
                .keyboardShortcut("l")
                .disabled(editor == nil)
            modeButton(.match, key: "1")
            modeButton(.replace, key: "2")
            modeButton(.filter, key: "3")

            Divider()

            Button("Show Code") { showCode?.show() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(showCode == nil)
        }

        CommandGroup(before: .help) {
            Button("Regex Cheat Sheet") { openWindow(id: CheatSheetView.windowID) }
                .keyboardShortcut("/", modifiers: [.command, .option])
            Divider()
        }
    }

    private func modeButton(_ mode: ExplorerMode, key: KeyEquivalent) -> some View {
        Toggle(mode.title, isOn: Binding(
            get: { editor?.mode == mode },
            set: { _ in editor?.setMode(mode) }
        ))
        .keyboardShortcut(key)
        .disabled(editor == nil)
    }
}
