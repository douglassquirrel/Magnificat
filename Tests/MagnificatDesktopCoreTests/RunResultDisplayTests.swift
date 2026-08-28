import Foundation
import Testing
@testable import MagnificatDesktopCore

// DESKTOP-SPEC.md §6 — all display text is pure, computed from RunResult, and
// fully testable without touching disk. The SwiftUI view only renders what these
// properties hand it.

func makeResult(_ results: [FileResult], topLevelFailureReason: String? = nil) -> RunResult {
    RunResult(status: RunStatus.compute(from: results, topLevelFailureReason: topLevelFailureReason),
              results: results, topLevelFailureReason: topLevelFailureReason,
              timestamp: Date(timeIntervalSince1970: 0),
              folder: URL(fileURLWithPath: "/tmp/unused"))
}

@Test func anEmptyBatchIsDoneWithNothingToDo() {
    let result = makeResult([])
    #expect(result.status == .done)
    #expect(result.headline == "DONE")
    #expect(result.detail == "Nothing to do — FOLDER/in was empty.")
    #expect(result.outputFilenameToDisplay == nil)
}

@Test func exactlyOneFileSucceedingShowsItsFilenameWithNoExtraDetail() {
    let result = makeResult([FileResult(inputName: "song.musicxml",
                                        outcome: .succeeded(outputName: "song.txt", anomalyCount: 0))])
    #expect(result.status == .done)
    #expect(result.headline == "DONE")
    #expect(result.detail == nil)
    #expect(result.outputFilenameToDisplay == "song.txt")
}

@Test func exactlyOneFileFailingIsAFailedRun() {
    let result = makeResult([FileResult(inputName: "broken.musicxml",
                                        outcome: .failed(reason: "not well-formed XML"))])
    #expect(result.status == .failed)
    #expect(result.headline == "FAILED")
    #expect(result.detail == "not well-formed XML")
    #expect(result.outputFilenameToDisplay == nil)
}

@Test func aTopLevelFailureIsFailedRegardlessOfResults() {
    let result = makeResult([], topLevelFailureReason: "could not create FOLDER/out")
    #expect(result.status == .failed)
    #expect(result.headline == "FAILED")
    #expect(result.detail == "could not create FOLDER/out")
}

@Test func oneSuccessAmongFailuresIsStillDone() {
    // DESKTOP-SPEC.md §6: one real success is enough to call the run done, but
    // the count is always stated so a mixed result is never presented as clean.
    let result = makeResult([
        FileResult(inputName: "a.musicxml", outcome: .succeeded(outputName: "a.txt", anomalyCount: 0)),
        FileResult(inputName: "b.musicxml", outcome: .failed(reason: "empty score")),
    ])
    #expect(result.status == .done)
    #expect(result.headline == "DONE")
    #expect(result.detail == "1 of 2 succeeded")
    #expect(result.outputFilenameToDisplay == nil, "more than one file was processed")
}

@Test func allFilesFailingIsFailed() {
    let result = makeResult([
        FileResult(inputName: "a.musicxml", outcome: .failed(reason: "x")),
        FileResult(inputName: "b.musicxml", outcome: .failed(reason: "y")),
    ])
    #expect(result.status == .failed)
    #expect(result.detail == "0 of 2 succeeded")
}

@Test func allFilesSucceedingStillStatesTheCount() {
    let result = makeResult([
        FileResult(inputName: "a.musicxml", outcome: .succeeded(outputName: "a.txt", anomalyCount: 0)),
        FileResult(inputName: "b.musicxml", outcome: .succeeded(outputName: "b.txt", anomalyCount: 0)),
    ])
    #expect(result.status == .done)
    #expect(result.detail == "2 of 2 succeeded")
}

@Test func anomaliesOnASingleFileAreStatedRatherThanHidden() {
    let result = makeResult([FileResult(inputName: "song.musicxml",
                                        outcome: .succeeded(outputName: "song.txt", anomalyCount: 1))])
    #expect(result.status == .done)
    #expect(result.outputFilenameToDisplay == "song.txt")
    #expect(result.detail == "1 warning — see last-run.log")
}

@Test func multipleAnomaliesAreCountedInThePlural() {
    let result = makeResult([FileResult(inputName: "song.musicxml",
                                        outcome: .succeeded(outputName: "song.txt", anomalyCount: 3))])
    #expect(result.detail == "3 warnings — see last-run.log")
}

@Test func skippedFilesDoNotCountAsAttemptsOrSuccesses() {
    // A non-.musicxml file sitting in FOLDER/in must not make an otherwise
    // single-file run look like a batch, and must not affect done/failed.
    let result = makeResult([
        FileResult(inputName: "song.musicxml", outcome: .succeeded(outputName: "song.txt", anomalyCount: 0)),
        FileResult(inputName: "notes.txt", outcome: .skipped(reason: "not .musicxml")),
    ])
    #expect(result.status == .done)
    #expect(result.outputFilenameToDisplay == "song.txt")
    #expect(result.detail == nil)
}

// DESKTOP-SPEC.md §6 — the visible file list never requires scrolling: at most
// 6 entries, with a "+ n more" trailer beyond that.

func succeeded(_ name: String, output: String? = nil, anomalies: Int = 0) -> FileResult {
    FileResult(inputName: name, outcome: .succeeded(outputName: output ?? name.replacingOccurrences(of: ".musicxml", with: ".txt"), anomalyCount: anomalies))
}

@Test func showsEveryLineWhenSixOrFewer() {
    let result = makeResult((1...6).map { succeeded("f\($0).musicxml") })
    #expect(result.visibleFileLines.count == 6)
    #expect(result.visibleFileLines.last == "f6.musicxml → f6.txt")
}

@Test func capsAtSixWithATrailerBeyondThat() {
    let result = makeResult((1...9).map { succeeded("f\($0).musicxml") })
    #expect(result.visibleFileLines.count == 7)
    #expect(result.visibleFileLines[5] == "f6.musicxml → f6.txt")
    #expect(result.visibleFileLines[6] == "(+ 3 more — see last-run.log)")
}

@Test func formatsEachOutcomeKindOnTheVisibleList() {
    let result = makeResult([
        succeeded("a.musicxml"),
        FileResult(inputName: "b.musicxml", outcome: .failed(reason: "empty score")),
        FileResult(inputName: "c.txt", outcome: .skipped(reason: "not .musicxml")),
    ])
    #expect(result.visibleFileLines == [
        "a.musicxml → a.txt",
        "b.musicxml → FAILED: empty score",
        "c.txt (skipped: not .musicxml)",
    ])
}

// DESKTOP-SPEC.md §6 "The log" — full detail, overwritten every run.

@Test func logTextHasTheFullWorkedExampleShape() {
    let result = RunResult(
        status: .done,
        results: [
            succeeded("mayer.musicxml", output: "mayer.txt"),
            FileResult(inputName: "broken.musicxml",
                      outcome: .failed(reason: "not well-formed XML: line 1, ...")),
        ],
        timestamp: Date(timeIntervalSince1970: 1_798_034_591),   // 2026-12-23T14:03:11Z
        folder: URL(fileURLWithPath: "/Users/you/Documents/MagnificatDesktop"))

    let expected = """
    Magnificat Desktop — run at 2026-12-23T14:03:11Z
    Folder: /Users/you/Documents/MagnificatDesktop

    mayer.musicxml → mayer.txt
    broken.musicxml → FAILED: not well-formed XML: line 1, ...

    1 of 2 succeeded.
    """
    #expect(result.logText == expected)
}

@Test func logTextNamesAnomaliesOnASuccessfulFile() {
    let result = RunResult(
        status: .done,
        results: [succeeded("noisy.musicxml", output: "noisy.txt", anomalies: 2)],
        timestamp: Date(timeIntervalSince1970: 0),
        folder: URL(fileURLWithPath: "/f"))

    #expect(result.logText.contains("noisy.musicxml → noisy.txt (2 anomalies)"))
}

@Test func logTextForAnEmptyRunSaysSo() {
    let result = RunResult(status: .done, results: [],
                           timestamp: Date(timeIntervalSince1970: 0),
                           folder: URL(fileURLWithPath: "/f"))
    #expect(result.logText.contains("Nothing to do — FOLDER/in was empty."))
}

@Test func logTextForATopLevelFailureNamesTheReason() {
    let result = RunResult(status: .failed, results: [],
                           topLevelFailureReason: "could not create FOLDER/out: permission denied",
                           timestamp: Date(timeIntervalSince1970: 0),
                           folder: URL(fileURLWithPath: "/f"))
    #expect(result.logText.contains("FAILED: could not create FOLDER/out: permission denied"))
}

@Test func logTextClosingLineNeverReferencesTheLogItItsIn() {
    // detail() says "— see last-run.log" for the window, which is meaningless
    // (and a little odd) inside last-run.log itself. The closing summary line
    // must state the same facts without that phrase.
    let result = RunResult(
        status: .done,
        results: [succeeded("noisy.musicxml", output: "noisy.txt", anomalies: 2)],
        timestamp: Date(timeIntervalSince1970: 0),
        folder: URL(fileURLWithPath: "/f"))

    #expect(result.logText.hasSuffix("1 of 1 succeeded, 2 anomalies."))
    #expect(!result.logText.contains("last-run.log."))
}
