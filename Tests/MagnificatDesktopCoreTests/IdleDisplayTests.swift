import Foundation
import Testing
@testable import MagnificatDesktopCore

// The idle state — before any Run — shows what is currently in FOLDER/in.
// Smaller than RunResult's display logic (no success/failure semantics apply
// yet), but still pure and tested, and reuses the same visible-file cap.

@Test func idleDetailForAnEmptyFolder() {
    #expect(idleDetail(scanned: []) == "FOLDER/in is empty.")
}

@Test func idleDetailWhenNothingIsMusicXML() {
    let scanned = [ScannedFile(url: URL(fileURLWithPath: "/f/notes.txt"),
                               name: "notes.txt", isMusicXML: false)]
    #expect(idleDetail(scanned: scanned) == "FOLDER/in has no .musicxml files.")
}

@Test func idleDetailCountsReadyFiles() {
    let scanned = [
        ScannedFile(url: URL(fileURLWithPath: "/f/a.musicxml"), name: "a.musicxml", isMusicXML: true),
        ScannedFile(url: URL(fileURLWithPath: "/f/b.musicxml"), name: "b.musicxml", isMusicXML: true),
    ]
    #expect(idleDetail(scanned: scanned) == "2 files ready in FOLDER/in.")
}

@Test func idleDetailUsesSingularForOneFile() {
    let scanned = [ScannedFile(url: URL(fileURLWithPath: "/f/a.musicxml"), name: "a.musicxml", isMusicXML: true)]
    #expect(idleDetail(scanned: scanned) == "1 file ready in FOLDER/in.")
}

@Test func idleVisibleLinesCapsLikeARunResultDoes() {
    let scanned = (1...9).map {
        ScannedFile(url: URL(fileURLWithPath: "/f/f\($0).musicxml"), name: "f\($0).musicxml", isMusicXML: true)
    }
    let lines = idleVisibleLines(scanned: scanned)
    #expect(lines.count == 7)
    #expect(lines.last == "(+ 3 more — see last-run.log)")
}

@Test func idleVisibleLinesMarksSkippedFiles() {
    let scanned = [ScannedFile(url: URL(fileURLWithPath: "/f/notes.txt"), name: "notes.txt", isMusicXML: false)]
    #expect(idleVisibleLines(scanned: scanned) == ["notes.txt (skipped: not .musicxml)"])
}
