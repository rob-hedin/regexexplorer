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

    /// With `eachLine`, every line is matched on its own, as Filter mode does: `^` and `$`
    /// match at each line's ends and no match runs past a line break.
    static func evaluate(
        pattern: String,
        options: RegexOptions,
        in text: String,
        eachLine: Bool = false,
        matchLimit: Int = defaultMatchLimit
    ) -> RegexEvaluation {
        guard !pattern.isEmpty else { return .noPattern }

        let regex: Regex<AnyRegexOutput>
        do {
            regex = try makeRegex(pattern: pattern, options: options)
        } catch {
            return .invalidPattern(String(describing: error))
        }

        // `matches(of:)` always finds every match. `replacing` stops after `maxReplacements`,
        // so it collects one more than the limit (to know there are more) and no further.
        var matches: [RegexMatch] = []
        let wanted = matchLimit == .max ? .max : matchLimit + 1
        // A substring is matched as if it were the whole text, and its ranges are the text's.
        var subjects = eachLine
            ? text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            : [text[...]]
        // As in LineFilter, a final newline ends the last line rather than starting an empty one.
        if eachLine, subjects.count > 1, subjects.last?.isEmpty == true {
            subjects.removeLast()
        }
        for subject in subjects where matches.count < wanted {
            _ = subject.replacing(regex, maxReplacements: wanted - matches.count) { match in
                let groups = match.output.dropFirst().enumerated().map { offset, element in
                    CaptureGroup(number: offset + 1, name: element.name, range: element.range)
                }
                matches.append(RegexMatch(range: match.range, groups: groups))
                return ""
            }
        }
        let truncated = matches.count > matchLimit
        return .matches(truncated ? Array(matches.prefix(matchLimit)) : matches, truncated: truncated)
    }

    /// Evaluates on one of a few dedicated threads, so a pattern that backtracks for a long
    /// time can't stall the caller. Returns `nil` as soon as the calling task is cancelled.
    static func evaluateInBackground(
        pattern: String,
        options: RegexOptions,
        in text: String,
        eachLine: Bool = false,
        matchLimit: Int = defaultMatchLimit
    ) async -> RegexEvaluation? {
        await MatchWorkers.shared.run {
            evaluate(pattern: pattern, options: options, in: text, eachLine: eachLine, matchLimit: matchLimit)
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

/// A small, fixed set of threads that evaluations run on.
///
/// Swift Regex can't be interrupted, so a cancelled evaluation keeps its thread busy until it
/// finishes, and its result is dropped. Capping the threads keeps runaway patterns from piling
/// up: once every thread is busy, new work waits in a queue that cancelled requests leave.
/// Dedicated threads are used rather than the shared concurrency pool, which runaway patterns
/// would otherwise tie up.
final class MatchWorkers: Sendable {
    static let shared = MatchWorkers(threadLimit: 3)

    private struct Job: Sendable {
        let id: UInt64
        let work: @Sendable () -> RegexEvaluation
    }

    private struct State: Sendable {
        var runningThreads = 0
        var queue: [Job] = []
        var waiting: [UInt64: CheckedContinuation<RegexEvaluation?, Never>] = [:]
        var lastID: UInt64 = 0
    }

    private let threadLimit: Int
    private let state = OSAllocatedUnfairLock(initialState: State())

    init(threadLimit: Int) {
        self.threadLimit = threadLimit
    }

    /// Runs `work` on a worker thread and returns its result, or `nil` if the task is cancelled first.
    func run(_ work: @escaping @Sendable () -> RegexEvaluation) async -> RegexEvaluation? {
        let id = state.withLock { state in
            state.lastID += 1
            return state.lastID
        }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let startsThread = state.withLock { state -> Bool? in
                    guard !Task.isCancelled else { return nil }
                    state.waiting[id] = continuation
                    guard state.runningThreads < threadLimit else {
                        state.queue.append(Job(id: id, work: work))
                        return false
                    }
                    state.runningThreads += 1
                    return true
                }
                switch startsThread {
                case nil: continuation.resume(returning: nil)
                case true?: startThread(with: Job(id: id, work: work))
                case false?: break
                }
            }
        } onCancel: {
            let continuation = state.withLock { state in
                state.queue.removeAll { $0.id == id }
                return state.waiting.removeValue(forKey: id)
            }
            continuation?.resume(returning: nil)
        }
    }

    /// Starts a thread that runs `job`, then queued jobs until the queue is empty.
    private func startThread(with job: Job) {
        let thread = Thread { [self] in
            var next: Job? = job
            while let job = next {
                let result = job.work()
                let continuation: CheckedContinuation<RegexEvaluation?, Never>?
                (continuation, next) = state.withLock { state in
                    let continuation = state.waiting.removeValue(forKey: job.id)
                    guard !state.queue.isEmpty else {
                        state.runningThreads -= 1
                        return (continuation, nil)
                    }
                    return (continuation, state.queue.removeFirst())
                }
                continuation?.resume(returning: result)
            }
        }
        thread.qualityOfService = .userInitiated
        // The same stack as the main thread, where patterns were evaluated before.
        thread.stackSize = 8 << 20
        thread.start()
    }
}
