// Copyright © 2026 Robert Hedin

import SwiftUI

/// A row of toggles for the optional settings on a regex.
struct RegexOptionsBar: View {
    @Binding var options: RegexOptions

    var body: some View {
        FlowLayout(spacing: 6) {
            option("Ignore case", isOn: $options.ignoresCase,
                   help: "Letters match regardless of case.")
            option("^ $ match each line", isOn: $options.anchorsMatchLineEndings,
                   help: "^ and $ match at the start and end of every line, not just the whole text.")
            option(". matches newlines", isOn: $options.dotMatchesNewlines,
                   help: ". also matches newline characters.")
            option("Ignore whitespace", isOn: $options.allowsExtendedSyntax,
                   help: "Whitespace in the pattern is ignored and # starts a comment.")
            option("Simple word boundaries", isOn: $options.usesSimpleWordBoundaries,
                   help: "\\b uses simple word-character transitions instead of Unicode word rules.")
        }
        .toggleStyle(.button)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Options")
    }

    private func option(_ title: LocalizedStringKey, isOn: Binding<Bool>, help: LocalizedStringKey) -> some View {
        Toggle(title, isOn: isOn)
            .help(help)
    }
}

/// Lays out its children in rows, wrapping to a new row when the next one doesn't fit.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, width maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let neededWidth = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if neededWidth > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }
}
