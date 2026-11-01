// Copyright © 2026 Robert Hedin

import Foundation
import os

/// One capture group within a match. Group 0 (the whole match) is not included.
struct CaptureGroup: Hashable, Sendable {
    /// 1-based group number, in the order the groups open in the pattern.
    let number: Int
    /// The group's name, for named groups such as `(?<year>\d{4})`.
    let name: String?
    /// Where the group matched in the text, or `nil` if it did not take part in the match.
    let range: Range<String.Index>?
}

/// One match of a regex in a piece of text.
struct RegexMatch: Hashable, Sendable {
    let range: Range<String.Index>
    let groups: [CaptureGroup]
}

/// The result of applying a pattern to some text.
enum RegexEvaluation: Equatable, Sendable {
    /// The pattern is empty, so there is nothing to match.
    case noPattern
    /// The pattern does not compile. The message describes why.
    case invalidPattern(String)
    /// The matches found. `truncated` is true when more matches exist than were returned.
    case matches([RegexMatch], truncated: Bool)
}

/// Compiles patterns with ``RegexOptions`` and finds their matches using Swift Regex.
enum RegexEvaluator {
    /// The most matches reported for one evaluation, to keep highlighting responsive.
    static let defaultMatchLimit = 1_000

    static func evaluate(
        pattern: String,
        options: RegexOptions,
        in text: String,
        matchLimit: Int = defaultMatchLimit
    ) -> RegexEvaluation {
        guard !pattern.isEmpty else { return .noPattern }

        let regex: Regex<AnyRegexOutput>
        do {
            regex = try makeRegex(pattern: pattern, options: options)
        } catch {
            return .invalidPattern(String(describing: error))
        }

        let found = text.matches(of: regex)
        let matches = found.prefix(matchLimit).map { match in
            let groups = match.output.dropFirst().enumerated().map { offset, element in
                CaptureGroup(number: offset + 1, name: element.name, range: element.range)
            }
            return RegexMatch(range: match.range, groups: groups)
        }
        return .matches(matches, truncated: found.count > matchLimit)
    }

    /// Evaluates on a thread of its own, so a pattern that backtracks for a long time can't
    /// stall the caller. Returns `nil` as soon as the calling task is cancelled. Swift Regex
    /// can't be interrupted, so the thread finishes the work and its result is dropped.
    static func evaluateInBackground(
        pattern: String,
        options: RegexOptions,
        in text: String,
        matchLimit: Int = defaultMatchLimit
    ) async -> RegexEvaluation? {
        let pending = OSAllocatedUnfairLock<CheckedContinuation<RegexEvaluation?, Never>?>(initialState: nil)
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                pending.withLock { $0 = continuation }
                if Task.isCancelled {
                    pending.withLock { $0.take() }?.resume(returning: nil)
                    return
                }
                // A dedicated thread rather than the shared pool, which a few runaway
                // patterns could otherwise use up.
                let thread = Thread {
                    let evaluation = evaluate(pattern: pattern, options: options, in: text, matchLimit: matchLimit)
                    pending.withLock { $0.take() }?.resume(returning: evaluation)
                }
                thread.qualityOfService = .userInitiated
                // The same stack as the main thread, where patterns were evaluated before.
                thread.stackSize = 8 << 20
                thread.start()
            }
        } onCancel: {
            pending.withLock { $0.take() }?.resume(returning: nil)
        }
    }

    static func makeRegex(pattern: String, options: RegexOptions) throws -> Regex<AnyRegexOutput> {
        // Swift Regex has no modifier method for extended syntax, so use the inline flag.
        var regex = try Regex(options.allowsExtendedSyntax ? "(?x)" + pattern : pattern)
        // Only apply options that are switched on, so inline flags in the pattern still work.
        if options.ignoresCase {
            regex = regex.ignoresCase()
        }
        if options.anchorsMatchLineEndings {
            regex = regex.anchorsMatchLineEndings()
        }
        if options.dotMatchesNewlines {
            regex = regex.dotMatchesNewlines()
        }
        if options.usesSimpleWordBoundaries {
            regex = regex.wordBoundaryKind(.simple)
        }
        return regex
    }
}
