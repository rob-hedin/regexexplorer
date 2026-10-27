import AppKit
import SwiftUI

/// The lower half of the editor: a Match / Replace / Filter switch and the read-only result for that mode.
struct ResultsView: View {
    @Binding var regex: SavedRegex
    let evaluation: RegexEvaluation

    private var text: String { regex.sampleText }

    /// The matches, when there is a valid pattern and some text to apply it to.
    private var found: (matches: [RegexMatch], truncated: Bool)? {
        guard case .matches(let matches, let truncated) = evaluation, !text.isEmpty else { return nil }
        return (matches, truncated)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if regex.mode == .replace {
                ReplacementField(replacement: $regex.replacement)
            }
            if let found {
                switch regex.mode {
                case .match:
                    MatchResultsView(text: text, matches: found.matches, truncated: found.truncated)
                case .replace:
                    ReplaceResultsView(result: RegexReplacer.replace(in: text, matches: found.matches, template: regex.replacement))
                case .filter:
                    FilterResultsView(result: LineFilter.filter(text, matches: found.matches, inverted: regex.invertsFilter))
                }
            } else {
                ResultPlaceholder(message: placeholderMessage)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Picker("Mode", selection: $regex.mode) {
                ForEach(ExplorerMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            if let summary {
                Text(summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            switch regex.mode {
            case .match:
                if let found {
                    GroupLegend(columns: MatchPresentation.groupColumns(for: found.matches))
                }
            case .replace:
                EmptyView()
            case .filter:
                Toggle("Drop matching lines", isOn: $regex.invertsFilter)
                    .toggleStyle(.button)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .help("Keep the lines without a match instead of those with one.")
            }
        }
    }

    private var summary: LocalizedStringKey? {
        guard let found else { return nil }
        let count = found.matches.count
        switch regex.mode {
        case .match:
            return found.truncated ? "\(count)+ matches" : "^[\(count) match](inflect: true)"
        case .replace:
            return "^[\(count) replacement](inflect: true)"
        case .filter:
            let result = LineFilter.filter(text, matches: found.matches, inverted: regex.invertsFilter)
            return "\(result.lines.count) of ^[\(result.totalLineCount) line](inflect: true)"
        }
    }

    private var placeholderMessage: LocalizedStringKey {
        switch evaluation {
        case .noPattern: "Type a pattern to see the result."
        case .invalidPattern: "Fix the pattern to see the result."
        case .matches: "Add some test text to see the result."
        }
    }
}

/// The highlighted matches and the match table.
struct MatchResultsView: View {
    let text: String
    let matches: [RegexMatch]
    let truncated: Bool

    var body: some View {
        ResultTextBox(text: MatchPresentation.highlightedText(text, matches: matches), label: "Test text with matches highlighted")
        if truncated {
            Text("Showing the first \(matches.count) matches.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if matches.isEmpty {
            ResultPlaceholder(message: "No matches.")
        } else {
            MatchTable(text: text, matches: matches)
        }
    }
}

private struct ReplacementField: View {
    @Binding var replacement: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Replace With")
            TextField("Replace with", text: $replacement, prompt: Text("Replacement, such as <$0>"))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14, design: .monospaced))
                .autocorrectionDisabled()
            Text("Use $0 for the whole match, $1 or ${name} for a group, and $$ for a literal $.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 4)
    }
}

private struct ReplaceResultsView: View {
    let result: ReplacementResult

    var body: some View {
        ResultHeader(copyText: result.text)
        ResultTextBox(
            text: MatchPresentation.highlighted(result.text, ranges: result.replacedRanges),
            label: "Replacement result",
            fillsHeight: true
        )
    }
}

private struct FilterResultsView: View {
    let result: FilterResult

    var body: some View {
        ResultHeader(copyText: result.text)
        if result.lines.isEmpty {
            ResultPlaceholder(message: "No lines left.")
        } else {
            ScrollView {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 4) {
                    ForEach(result.lines, id: \.number) { line in
                        GridRow {
                            Text("\(line.number)")
                                .foregroundStyle(.secondary)
                                .gridColumnAlignment(.trailing)
                                .accessibilityLabel("Line \(line.number)")
                            Text(MatchPresentation.highlighted(line.text, ranges: line.matchRanges))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .font(.system(.body, design: .monospaced))
                .padding(10)
            }
            .frame(maxHeight: .infinity)
            .background(.quinary, in: .rect(cornerRadius: 7))
            Text("Line numbers show where each line came from. They aren't included when you copy.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// "Result" with a Copy button.
private struct ResultHeader: View {
    let copyText: String

    var body: some View {
        HStack {
            SectionLabel("Result")
            Spacer()
            Button("Copy", systemImage: "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(copyText, forType: .string)
            }
            .controlSize(.small)
        }
    }
}

/// Read-only, selectable text in a tinted box.
private struct ResultTextBox: View {
    let text: AttributedString
    let label: LocalizedStringKey
    var fillsHeight = false

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.body, design: .monospaced))
                .lineSpacing(4)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        }
        .frame(minHeight: 50, maxHeight: fillsHeight ? .infinity : 160)
        .fixedSize(horizontal: false, vertical: !fillsHeight)
        .background(.quinary, in: .rect(cornerRadius: 7))
        .accessibilityLabel(label)
    }
}

private struct ResultPlaceholder: View {
    let message: LocalizedStringKey

    var body: some View {
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
