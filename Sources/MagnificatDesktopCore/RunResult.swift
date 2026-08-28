import Foundation
import Magnificat

/// What happened to one file in a run. See `DESKTOP-SPEC.md` §4, §6.
public enum FileOutcome: Sendable, Equatable {
    /// Transcribed and written to `outputName` in `FOLDER/out`. `anomalies` are
    /// the musical-coherence anomalies (`SPEC.md` §6.15) found — empty for a
    /// clean file. Non-empty is still a success; each anomaly's own
    /// `measureNumber` and `detail` are what let the log say specifically
    /// where and what, rather than just a bare count. Reused directly from
    /// `Magnificat.Anomaly`, whose `detail` is documented as "safe to show a
    /// user" — exactly this use.
    case succeeded(outputName: String, anomalies: [Anomaly])
    /// Could not be transcribed. Nothing was written for this file.
    case failed(reason: String)
    /// Not a `.musicxml` file, or a subdirectory. Never opened.
    case skipped(reason: String)
}

/// One input file's result within a run.
public struct FileResult: Sendable, Equatable {
    public var inputName: String
    public var outcome: FileOutcome

    public init(inputName: String, outcome: FileOutcome) {
        self.inputName = inputName
        self.outcome = outcome
    }
}

/// The four states `DESKTOP-SPEC.md` §6 names: idle, running, done, failed.
public enum RunStatus: Sendable, Equatable {
    case idle, running, done, failed

    /// `.failed` when at least one file was attempted and none succeeded, or
    /// `topLevelFailureReason` says the run could not start at all. `.done`
    /// otherwise — including an empty batch, and including a mixed batch where
    /// at least one file succeeded. `DESKTOP-SPEC.md` §6.
    static func compute(from results: [FileResult], topLevelFailureReason: String?) -> RunStatus {
        if topLevelFailureReason != nil { return .failed }
        let attempted = results.filter {
            if case .skipped = $0.outcome { return false }
            return true
        }
        guard !attempted.isEmpty else { return .done }
        let succeeded = attempted.contains {
            if case .succeeded = $0.outcome { return true }
            return false
        }
        return succeeded ? .done : .failed
    }
}

/// The outcome of one Run, and everything needed to display and log it.
public struct RunResult: Sendable, Equatable {
    public var status: RunStatus
    public var results: [FileResult]
    /// Set when the run could not start at all — the folder was unreadable, or
    /// `FOLDER/out` could not be created. Distinct from a per-file failure.
    public var topLevelFailureReason: String?
    public var timestamp: Date
    public var folder: URL

    public init(status: RunStatus, results: [FileResult], topLevelFailureReason: String? = nil,
                timestamp: Date, folder: URL) {
        self.status = status
        self.results = results
        self.topLevelFailureReason = topLevelFailureReason
        self.timestamp = timestamp
        self.folder = folder
    }
}
