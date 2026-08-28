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

@Test func outputNameStripsTheCompressedExtensionToo() {
    // Found alongside the InputScan fix: scanInputFolder now recognizes .mxl,
    // and the output name must not just append .txt onto it wholesale
    // ("song.mxl.txt") the way the fallback branch would for an unrecognized
    // extension.
    #expect(Runner.outputName(for: "song.mxl") == "song.txt")
    #expect(Runner.outputName(for: "Song.MXL") == "Song.txt")
}

// Every TranscriptionError case gets its own log/window wording, tested
// directly against Runner.describe rather than through six different
// malformed files — the point here is the string mapping, and the main
// library's own test suite already thoroughly covers error *production*.

@Test func describesEveryTranscriptionErrorCase() {
    let cases: [(TranscriptionError, contains: String)] = [
        (.malformedXML(line: 3, message: "oops"), "not well-formed XML"),
        (.unsupportedRootElement(found: "html"), "not a partwise MusicXML score"),
        (.corruptedArchive("no container.xml"), "could not read the .mxl archive"),
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

// No Runner code changes were needed for .mxl support — Score(musicXML:)
// handles it transparently — but this proves the wiring actually reaches a
// real folder-driven run, not just the library's own unit tests. A minimal
// STORED-method (uncompressed) archive is built by hand rather than reusing
// the real Fixtures/mxl/ files, which live in MagnificatTests's own resource
// bundle and are not visible from this target.

func minimalStoredMxl(scoreContent: Data) -> Data {
    func u16(_ v: UInt16) -> [UInt8] { [UInt8(v & 0xFF), UInt8(v >> 8)] }
    func u32(_ v: UInt32) -> [UInt8] {
        [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)]
    }
    let container = Data("""
    <container><rootfiles><rootfile full-path="score.xml"/></rootfiles></container>
    """.utf8)

    func localHeader(name: String, content: Data) -> Data {
        let nameBytes = Data(name.utf8)
        var header = Data()
        header.append(contentsOf: u32(0x0403_4B50)); header.append(contentsOf: u16(20))
        header.append(contentsOf: u16(0)); header.append(contentsOf: u16(0))  // flags, method=0 (stored)
        header.append(contentsOf: u16(0)); header.append(contentsOf: u16(0))  // time, date
        header.append(contentsOf: u32(0))                                     // crc32
        header.append(contentsOf: u32(UInt32(content.count)))                 // compressed size
        header.append(contentsOf: u32(UInt32(content.count)))                 // uncompressed size
        header.append(contentsOf: u16(UInt16(nameBytes.count))); header.append(contentsOf: u16(0))
        header.append(nameBytes)
        header.append(content)
        return header
    }
    func centralRecord(name: String, content: Data, offset: UInt32) -> Data {
        let nameBytes = Data(name.utf8)
        var record = Data()
        record.append(contentsOf: u32(0x0201_4B50))
        record.append(contentsOf: u16(20)); record.append(contentsOf: u16(20))
        record.append(contentsOf: u16(0)); record.append(contentsOf: u16(0))
        record.append(contentsOf: u16(0)); record.append(contentsOf: u16(0))
        record.append(contentsOf: u32(0))
        record.append(contentsOf: u32(UInt32(content.count)))
        record.append(contentsOf: u32(UInt32(content.count)))
        record.append(contentsOf: u16(UInt16(nameBytes.count)))
        record.append(contentsOf: u16(0)); record.append(contentsOf: u16(0))
        record.append(contentsOf: u16(0)); record.append(contentsOf: u16(0))
        record.append(contentsOf: u32(0))
        record.append(contentsOf: u32(offset))
        record.append(nameBytes)
        return record
    }

    var body = Data()
    let containerOffset: UInt32 = 0
    body.append(localHeader(name: "META-INF/container.xml", content: container))
    let scoreOffset = UInt32(body.count)
    body.append(localHeader(name: "score.xml", content: scoreContent))

    var centralDirectory = Data()
    centralDirectory.append(centralRecord(name: "META-INF/container.xml", content: container, offset: containerOffset))
    centralDirectory.append(centralRecord(name: "score.xml", content: scoreContent, offset: scoreOffset))

    var archive = body
    let cdOffset = UInt32(archive.count)
    archive.append(centralDirectory)
    archive.append(contentsOf: u32(0x0605_4B50))
    archive.append(contentsOf: u16(0)); archive.append(contentsOf: u16(0))
    archive.append(contentsOf: u16(2)); archive.append(contentsOf: u16(2))
    archive.append(contentsOf: u32(UInt32(centralDirectory.count)))
    archive.append(contentsOf: u32(cdOffset))
    archive.append(contentsOf: u16(0))
    return archive
}

@Test func transcribesARealMxlFileDroppedIntoFolderIn() throws {
    let folder = makeFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let archive = minimalStoredMxl(scoreContent: validMusicXML)
    try archive.write(to: folder.appendingPathComponent("in/song.mxl"))

    let result = Runner().run(folder: folder, now: Date(timeIntervalSince1970: 0))

    #expect(result.status == .done)
    guard case .succeeded(let outputName, let anomalies) = result.results.first?.outcome else {
        Issue.record("expected a success, got \(String(describing: result.results.first))")
        return
    }
    #expect(outputName == "song.txt")
    #expect(anomalies.isEmpty)
    let written = try String(contentsOf: folder.appendingPathComponent("out/song.txt"), encoding: .utf8)
    #expect(written == (try transcribe(musicXML: validMusicXML)))
}
