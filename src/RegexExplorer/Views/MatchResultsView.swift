import SwiftUI

/// The read-only results: the test text with matches highlighted, and a table of each match.
struct MatchResultsView: View {
    let text: String
    let evaluation: RegexEvaluation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            switch evaluation {
            case .noPattern:
                placeholder("Type a pattern to see matches.")
            case .invalidPattern:
                placeholder("Fix the pattern to see matches.")
            case .matches where text.isEmpty:
                placeholder("Add some test text to see matches.")
            case .matches(let matches, let truncated):
                highlightedText(matches)
                if truncated {
                    Text("Showing the first \(matches.count) matches.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if matches.isEmpty {
                    placeholder("No matches.")
                } else {
                    MatchTable(text: text, matches: matches)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(spacing: 8) {
            SectionLabel("Matches")
            if case .matches(let matches, let truncated) = evaluation, !text.isEmpty {
                Text(truncated ? "\(matches.count)+" : "\(matches.count)")
                    .font(.caption)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: .capsule)
                Spacer()
                GroupLegend(columns: MatchPresentation.groupColumns(for: matches))
            }
        }
    }

    private func highlightedText(_ matches: [RegexMatch]) -> some View {
        ScrollView {
            Text(MatchPresentation.highlightedText(text, matches: matches))
                .font(.system(.body, design: .monospaced))
                .lineSpacing(4)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        }
        .frame(minHeight: 50, maxHeight: 160)
        .fixedSize(horizontal: false, vertical: true)
        .background(.quinary, in: .rect(cornerRadius: 7))
        .accessibilityLabel("Test text with matches highlighted")
    }

    private func placeholder(_ message: LocalizedStringKey) -> some View {
        Text(message)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(.quinary, in: .rect(cornerRadius: 7))
    }
}

/// Shows which underline colour belongs to which capture group.
private struct GroupLegend: View {
    let columns: [GroupColumn]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(columns) { column in
                HStack(spacing: 4) {
                    Capsule()
                        .fill(MatchPresentation.color(forGroup: column.id))
                        .frame(width: 14, height: 3)
                    Text(column.title)
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct MatchTable: View {
    let text: String
    let matches: [RegexMatch]

    var body: some View {
        let columns = MatchPresentation.groupColumns(for: matches)
        Table(MatchPresentation.rows(for: matches, in: text)) {
            TableColumn("#") { row in
                Text("\(row.id)")
            }
            .width(36)
            TableColumn("Match") { row in
                Text(row.text)
                    .font(.system(.body, design: .monospaced))
            }
            TableColumnForEach(columns) { column in
                TableColumn(column.title) { row in
                    Text(row.groupValues[column.index] ?? "—")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(row.groupValues[column.index] == nil ? .secondary : .primary)
                }
            }
            TableColumn("Position") { row in
                Text(row.position)
                    .foregroundStyle(.secondary)
            }
            .width(min: 70, ideal: 90)
        }
        .frame(minHeight: 120)
    }
}
