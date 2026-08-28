import Foundation

/// A one-line summary of what is currently in `FOLDER/in`, shown before any Run.
/// Mirrors `RunResult.detail`'s wording style, deliberately: an operator should
/// recognize the shape of the text whether or not a run has happened yet.
public func idleDetail(scanned: [ScannedFile]) -> String {
    guard !scanned.isEmpty else { return "FOLDER/in is empty." }
    let ready = scanned.filter(\.isMusicXML).count
    guard ready > 0 else { return "FOLDER/in has no .musicxml files." }
    return "\(ready) \(ready == 1 ? "file" : "files") ready in FOLDER/in."
}

/// The pre-run file listing, capped exactly like `RunResult.visibleFileLines` —
/// the same "no scrolling required" rule applies before a run as after one.
public func idleVisibleLines(scanned: [ScannedFile]) -> [String] {
    let lines = scanned.map { file in
        file.isMusicXML ? file.name : "\(file.name) (skipped: not .musicxml)"
    }
    guard lines.count > RunResult.visibleFileCap else { return lines }
    let shown = Array(lines.prefix(RunResult.visibleFileCap))
    let remaining = lines.count - RunResult.visibleFileCap
    return shown + ["(+ \(remaining) more — see last-run.log)"]
}
