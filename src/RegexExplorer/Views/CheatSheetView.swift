// Copyright © 2026 Robert Hedin

import SwiftUI

/// The contents of the cheat sheet window: regex syntax in searchable sections.
struct CheatSheetView: View {
    static let windowID = "cheat-sheet"

    @State private var searchText = ""

    var body: some View {
        let sections = CheatSheet.sections(matching: searchText)

        ScrollView {
            if sections.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 24, alignment: .top),
                                    GridItem(.flexible(), alignment: .top)],
                          alignment: .leading, spacing: 16) {
                    ForEach(sections) { section in
                        CheatSheetSectionView(section: section)
                    }
                }
                .padding(16)
            }
        }
        .searchable(text: $searchText, placement: .toolbar)
        .frame(minWidth: 460, minHeight: 400)
    }
}

private struct CheatSheetSectionView: View {
    let section: CheatSheetSection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(LocalizedStringKey(section.title))
                .padding(.bottom, 6)
            Divider()
            ForEach(section.entries, id: \.self) { entry in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(entry.token)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.tint)
                        .frame(width: 90, alignment: .leading)
                    Text(entry.meaning)
                        .font(.callout)
                }
                .textSelection(.enabled)
                .padding(.vertical, 4)
                Divider()
            }
        }
    }
}
