import Foundation
import Testing
@testable import MagnificatDesktopCore
import Magnificat

// DESKTOP-SPEC.md §6 "Run" — the effectful core: scan FOLDER/in fresh, transcribe
// each .musicxml file with default options, write FOLDER/out/<stem>.txt and
// FOLDER/out/last-run.log. Real temp directories throughout, per CLAUDE.md.

/// A minimal but complete score-partwise document — never a fragment.
let validMusicXML = Data("""
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Voice</part-name></score-part></part-list>
  <part id="P1"><measure number="1">
    <attributes><divisions>4</divisions></attributes>
    <note><pitch><step>C</step><octave>5</octave></pitch>
      <duration>4</duration><type>quarter</type></note>
  </measure></part>
</score-partwise>
""".utf8)

let malformedMusicXML = Data("<score-partwise><part-list></part-lst></score-partwise>".utf8)

func makeFolder() -> URL {
    let folder = tempDirectory()
    try! FileManager.default.createDirectory(
        at: folder.appendingPathComponent("in"), withIntermediateDirectories: true)
    try! FileManager.default.createDirectory(
        at: folder.appendingPathComponent("out"), withIntermediateDirectories: true)
    return folder
}

@Test func transcribesAValidFileAndWritesItsOutput() throws {
    let folder = makeFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    try validMusicXML.write(to: folder.appendingPathComponent("in/song.musicxml"))

    let result = Runner().run(folder: folder, now: Date(timeIntervalSince1970: 0))

    #expect(result.status == .done)
    #expect(result.results == [FileResult(inputName: "song.musicxml",
                                          outcome: .succeeded(outputName: "song.txt", anomalies: []))])

    let written = try String(contentsOf: folder.appendingPathComponent("out/song.txt"), encoding: .utf8)
    let expected = try transcribe(musicXML: validMusicXML)
    #expect(written == expected)
}

@Test func aMalformedFileFailsWithoutWritingOutput() throws {
    let folder = makeFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    try malformedMusicXML.write(to: folder.appendingPathComponent("in/broken.musicxml"))

    let result = Runner().run(folder: folder, now: Date(timeIntervalSince1970: 0))

    #expect(result.status == .failed)
    guard case .failed = result.results.first?.outcome else {
        Issue.record("expected a failure, got \(String(describing: result.results.first))")
        return
    }
    #expect(!FileManager.default.fileExists(
        atPath: folder.appendingPathComponent("out/broken.txt").path))
}

@Test func writesLastRunLogMatchingTheResult() throws {
    let folder = makeFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    try validMusicXML.write(to: folder.appendingPathComponent("in/song.musicxml"))

    let result = Runner().run(folder: folder, now: Date(timeIntervalSince1970: 0))

    let logged = try String(contentsOf: folder.appendingPathComponent("out/last-run.log"), encoding: .utf8)
    #expect(logged == result.logText)
}

@Test func skipsNonMusicXMLFilesWithoutOpeningThem() throws {
    let folder = makeFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    try Data("not xml at all".utf8).write(to: folder.appendingPathComponent("in/readme.txt"))

    let result = Runner().run(folder: folder, now: Date(timeIntervalSince1970: 0))

    #expect(result.status == .done)
    #expect(result.results == [FileResult(inputName: "readme.txt",
                                          outcome: .skipped(reason: "not .musicxml"))])
}

@Test func rerunningOverwritesThePreviousOutput() throws {
    let folder = makeFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let target = folder.appendingPathComponent("out/song.txt")
    try Data("stale content from a previous run".utf8).write(to: target)
    try validMusicXML.write(to: folder.appendingPathComponent("in/song.musicxml"))

    _ = Runner().run(folder: folder, now: Date(timeIntervalSince1970: 0))

    let written = try String(contentsOf: target, encoding: .utf8)
    #expect(!written.contains("stale content"))
}

@Test func anEmptyInputFolderProducesADoneRunWithALog() throws {
    let folder = makeFolder()
    defer { try? FileManager.default.removeItem(at: folder) }

    let result = Runner().run(folder: folder, now: Date(timeIntervalSince1970: 0))

    #expect(result.status == .done)
    #expect(result.results.isEmpty)
    #expect(FileManager.default.fileExists(
        atPath: folder.appendingPathComponent("out/last-run.log").path))
}

@Test func reportsATopLevelFailureWhenTheFolderCannotBeCreated() throws {
    let base = tempDirectory()
    defer { try? FileManager.default.removeItem(at: base) }
    let blocked = base.appendingPathComponent("blocked")
    try Data("not a directory".utf8).write(to: blocked)

    let result = Runner().run(folder: blocked, now: Date(timeIntervalSince1970: 0))

    #expect(result.status == .failed)
    #expect(result.topLevelFailureReason != nil)
    #expect(result.results.isEmpty)
}

@Test func createsInAndOutOnItsOwnIfMissing() throws {
    // Defensive: Run must not depend on some earlier launch-time step having
    // already created the folders.
    let folder = tempDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }

    let result = Runner().run(folder: folder, now: Date(timeIntervalSince1970: 0))

    #expect(result.status == .done)
    var isDir: ObjCBool = false
    #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("out").path, isDirectory: &isDir))
    #expect(isDir.boolValue)
}

@Test func theFailureReasonNamesWhatWentWrong() throws {
    let folder = makeFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    try malformedMusicXML.write(to: folder.appendingPathComponent("in/broken.musicxml"))

    let result = Runner().run(folder: folder, now: Date(timeIntervalSince1970: 0))

    guard case .failed(let reason) = result.results.first?.outcome else {
        Issue.record("expected a failure")
        return
    }
    #expect(reason.contains("not well-formed XML"))
    #expect(reason.contains("line"))
}

@Test func anomaliesInATranscriptAreCountedAsAWarningNotAFailure() throws {
    // An overfull measure — SPEC.md §6.15 — passes the schema and is a real
    // anomaly the library reports, but the transcript is still produced. This
    // must show up as a success with a non-zero anomaly count, never a failure.
    let overfull = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0">
      <part-list><score-part id="P1"><part-name>Voice</part-name></score-part></part-list>
      <part id="P1"><measure number="1">
        <attributes><divisions>4</divisions>
          <time><beats>4</beats><beat-type>4</beat-type></time></attributes>
        <note><pitch><step>C</step><octave>5</octave></pitch>
          <duration>16</duration><type>whole</type></note>
        <note><pitch><step>D</step><octave>5</octave></pitch>
          <duration>8</duration><type>half</type></note>
      </measure></part>
    </score-partwise>
    """.utf8)
    let folder = makeFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    try overfull.write(to: folder.appendingPathComponent("in/noisy.musicxml"))

    let result = Runner().run(folder: folder, now: Date(timeIntervalSince1970: 0))

    #expect(result.status == .done)
    guard case .succeeded(let outputName, let anomalies) = result.results.first?.outcome else {
        Issue.record("expected a success"); return
    }
    #expect(outputName == "noisy.txt")
    #expect(anomalies.count == 1)
    #expect(anomalies.first?.measureNumber == "1")
}

@Test func outputNameReplacesTheExtensionCaseInsensitively() {
    #expect(Runner.outputName(for: "song.musicxml") == "song.txt")
    #expect(Runner.outputName(for: "Song.MUSICXML") == "Song.txt")
    #expect(Runner.outputName(for: "a.b.musicxml") == "a.b.txt")
}

// Every TranscriptionError case gets its own log/window wording, tested
// directly against Runner.describe rather than through six different
// malformed files — the point here is the string mapping, and the main
// library's own test suite already thoroughly covers error *production*.

@Test func describesEveryTranscriptionErrorCase() {
    let cases: [(TranscriptionError, contains: String)] = [
        (.malformedXML(line: 3, message: "oops"), "not well-formed XML"),
        (.unsupportedRootElement(found: "html"), "not a partwise MusicXML score"),
        (.unsupportedFormat("compressed .mxl"), "unsupported format"),
        (.emptyScore, "empty score"),
        (.invalidValue(element: "octave", value: "banana"), "cannot mean anything"),
        // Never actually reachable through this app (no part/measure
        // subsetting — DESKTOP-SPEC.md §9), but the switch stays exhaustive.
        (.unknownPart("Trombone"), "no such part"),
        (.measureRangeOutOfBounds(requested: 90...100, available: 1...32), "outside"),
    ]
    for (error, expected) in cases {
        #expect(Runner.describe(error).contains(expected), "\(error)")
    }
}

@Test func outputNameFallsBackWhenTheNameDoesNotActuallyEndInMusicXML() {
    // Runner.process only ever calls this on names the scan already confirmed
    // end in .musicxml, so this fallback is not reachable through the real
    // pipeline — but outputName is itself public and testable, and its
    // contract should hold regardless of how a caller happens to use it.
    #expect(Runner.outputName(for: "weird") == "weird.txt")
    #expect(Runner.outputName(for: ".musicxml") == ".musicxml.txt")
}

@Test func anUnreadableFileFailsWithoutCrashing() throws {
    // process()'s generic catch — a non-TranscriptionError failure reading the
    // file. A first version of this test deleted the file between the scan
    // and the read to provoke it, but that just meant scanInputFolder never
    // saw it at all (an empty, correctly-.done run) — the intended race is not
    // reachable synchronously. A permission-denied file fails the same way,
    // deterministically, with no race required.
    let folder = makeFolder()
    defer {
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: folder.appendingPathComponent("in/locked.musicxml").path)
        try? FileManager.default.removeItem(at: folder)
    }
    let path = folder.appendingPathComponent("in/locked.musicxml")
    try validMusicXML.write(to: path)
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: path.path)

    let result = Runner().run(folder: folder, now: Date(timeIntervalSince1970: 0))

    #expect(result.status == .failed)
    guard case .failed = result.results.first?.outcome else {
        Issue.record("expected a failure, got \(String(describing: result.results.first))")
        return
    }
}
