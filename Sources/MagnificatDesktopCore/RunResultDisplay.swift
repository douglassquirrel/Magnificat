import Foundation

/// All the English the window shows for a run, computed here so the SwiftUI
/// layer only ever renders a string it is handed — mirroring how `Renderer`
/// keeps every word out of `MagnificatCLI` in the library proper.
/// See `DESKTOP-SPEC.md` §6.
extension RunResult {
    private var attempted: [FileResult] {
        results.filter {
            if case .skipped = $0.outcome { return false }
            return true
        }
    }

    private var succeededCount: Int {
        attempted.filter {
            if case .succeeded = $0.outcome { return true }
            return false
        }.count
    }

    private var totalAnomalies: Int {
        results.reduce(0) { sum, result in
            if case .succeeded(_, let anomalies) = result.outcome { return sum + anomalies.count }
            return sum
        }
    }

    /// `"DONE"` or `"FAILED"` — the large, high-contrast headline.
    public var headline: String {
        status == .failed ? "FAILED" : "DONE"
    }

    /// A one-line summary shown beneath the headline, or `nil` when nothing
    /// more needs saying — exactly one file, succeeded, no anomalies.
    ///
    /// This stays a bare count by design — `DESKTOP-SPEC.md` §6 caps the
    /// window at a handful of lines, and the log is where the detail behind
    /// the count belongs (`logText`, below).
    public var detail: String? {
        if let topLevelFailureReason { return topLevelFailureReason }
        if attempted.isEmpty { return "Nothing to do — FOLDER/in was empty." }
        if attempted.count == 1 {
            switch attempted[0].outcome {
            case .failed(let reason):
                return reason
            case .succeeded(_, let anomalies) where !anomalies.isEmpty:
                let count = anomalies.count
                return "\(count) \(count == 1 ? "warning" : "warnings") — see last-run.log"
            default:
                return nil
            }
        }
        var line = "\(succeededCount) of \(attempted.count) succeeded"
        if totalAnomalies > 0 {
            line += " · \(totalAnomalies) \(totalAnomalies == 1 ? "warning" : "warnings") — see last-run.log"
        }
        return line
    }

    /// The output filename, shown big, only when exactly one file was attempted
    /// and it succeeded — the common case the requirement itself describes in
    /// the singular. `nil` for a batch, a failure, or an empty run.
    public var outputFilenameToDisplay: String? {
        guard attempted.count == 1, case .succeeded(let name, _) = attempted[0].outcome else {
            return nil
        }
        return name
    }

    /// The number of file lines shown before the "+ n more" trailer kicks in.
    /// `DESKTOP-SPEC.md` §6: "the visible file list never requires scrolling."
    static let visibleFileCap = 6

    /// One formatted line per result, capped so the window never needs to
    /// scroll — the remainder is summarized in a trailer line, and always
    /// present in full in `logText`.
    public var visibleFileLines: [String] {
        let lines = results.map(Self.line(for:))
        guard lines.count > Self.visibleFileCap else { return lines }
        let shown = Array(lines.prefix(Self.visibleFileCap))
        let remaining = lines.count - Self.visibleFileCap
        return shown + ["(+ \(remaining) more — see last-run.log)"]
    }

    private static func line(for result: FileResult) -> String {
        switch result.outcome {
        case .succeeded(let outputName, _):
            return "\(result.inputName) → \(outputName)"
        case .failed(let reason):
            return "\(result.inputName) → FAILED: \(reason)"
        case .skipped(let reason):
            return "\(result.inputName) (skipped: \(reason))"
        }
    }

    /// The complete text of `FOLDER/out/last-run.log`. Overwritten every run —
    /// this is the record of the *most recent* run only. `DESKTOP-SPEC.md` §6.
    ///
    /// Every anomaly is listed here with its measure number and detail —
    /// Cowork feedback, 28 August 2026: a bare "(2 anomalies)" said nothing
    /// carries the words down to where the count was previously the dead end.
    public var logText: String {
        let formatter = ISO8601DateFormatter()
        var lines = [
            "Magnificat Desktop — run at \(formatter.string(from: timestamp))",
            "Folder: \(folder.path)",
            "",
        ]

        if let topLevelFailureReason {
            lines.append("FAILED: \(topLevelFailureReason)")
        } else if results.isEmpty {
            lines.append("Nothing to do — FOLDER/in was empty.")
        } else {
            lines += results.flatMap(Self.logLines(for:))
            lines.append("")
            lines.append(logSummaryLine)
        }
        return lines.joined(separator: "\n")
    }

    /// The log's own closing line — the same facts `detail` states for the
    /// window, but self-contained: it never says "see last-run.log", which
    /// would be meaningless (and odd) inside last-run.log itself.
    private var logSummaryLine: String {
        var line = "\(succeededCount) of \(attempted.count) succeeded"
        if totalAnomalies > 0 {
            line += ", \(totalAnomalies) \(totalAnomalies == 1 ? "anomaly" : "anomalies")"
        }
        return line + "."
    }

    /// One or more lines for a single file: the summary line, then one
    /// indented line per anomaly naming its measure and what was found. The
    /// window only ever shows a count for anomalies and points here for the
    /// rest — this is that "rest".
    private static func logLines(for result: FileResult) -> [String] {
        switch result.outcome {
        case .succeeded(let outputName, let anomalies):
            let suffix = anomalies.isEmpty ? "" : " (\(anomalies.count) anomalies)"
            var lines = ["\(result.inputName) → \(outputName)\(suffix)"]
            lines += anomalies.map { "  measure \($0.measureNumber): \($0.detail)" }
            return lines
        case .failed(let reason):
            return ["\(result.inputName) → FAILED: \(reason)"]
        case .skipped(let reason):
            return ["\(result.inputName): skipped: \(reason)"]
        }
    }
}
