import Foundation
import Testing
@testable import MagnificatDesktopCore

// DESKTOP-SPEC.md §6 — non-recursive, .musicxml matched case-insensitively;
// everything else is listed too, but marked skipped and never opened.

@Test func listsMusicXMLFilesSortedByName() throws {
    let inDir = tempDirectory()
    defer { try? FileManager.default.removeItem(at: inDir) }
    for name in ["beta.musicxml", "alpha.musicxml"] {
        try Data().write(to: inDir.appendingPathComponent(name))
    }

    let scanned = try scanInputFolder(inDir)

    #expect(scanned.map(\.name) == ["alpha.musicxml", "beta.musicxml"])
    #expect(scanned.allSatisfy { $0.isMusicXML })
}

@Test func matchesTheExtensionCaseInsensitively() throws {
    let inDir = tempDirectory()
    defer { try? FileManager.default.removeItem(at: inDir) }
    try Data().write(to: inDir.appendingPathComponent("Song.MUSICXML"))

    let scanned = try scanInputFolder(inDir)

    #expect(scanned.first?.isMusicXML == true)
}

@Test func listsButMarksNonMusicXMLFilesAsSkipped() throws {
    let inDir = tempDirectory()
    defer { try? FileManager.default.removeItem(at: inDir) }
    try Data().write(to: inDir.appendingPathComponent("notes.txt"))

    let scanned = try scanInputFolder(inDir)

    #expect(scanned.count == 1)
    #expect(scanned.first?.isMusicXML == false)
}

@Test func listsButDoesNotDescendIntoSubdirectories() throws {
    // A subdirectory is listed like anything else non-.musicxml, so the operator
    // can see it is there and why it was skipped — but its contents are never
    // examined. This was written expecting the subdirectory to vanish entirely;
    // that contradicted scanInputFolder's own documented behavior ("every entry
    // is listed... so the caller can show the operator why something was
    // skipped"), so the test's expectation was corrected, not the code.
    let inDir = tempDirectory()
    defer { try? FileManager.default.removeItem(at: inDir) }
    let nested = inDir.appendingPathComponent("nested")
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try Data().write(to: nested.appendingPathComponent("hidden.musicxml"))
    try Data().write(to: inDir.appendingPathComponent("visible.musicxml"))

    let scanned = try scanInputFolder(inDir)

    #expect(scanned.map(\.name) == ["nested", "visible.musicxml"])
    #expect(scanned.first { $0.name == "nested" }?.isMusicXML == false)
}

@Test func ignoresDotfiles() throws {
    // .DS_Store and similar Finder litter should never appear in the listing.
    let inDir = tempDirectory()
    defer { try? FileManager.default.removeItem(at: inDir) }
    try Data().write(to: inDir.appendingPathComponent(".DS_Store"))
    try Data().write(to: inDir.appendingPathComponent("song.musicxml"))

    let scanned = try scanInputFolder(inDir)

    #expect(scanned.map(\.name) == ["song.musicxml"])
}

@Test func anEmptyFolderScansToAnEmptyList() throws {
    let inDir = tempDirectory()
    defer { try? FileManager.default.removeItem(at: inDir) }

    #expect(try scanInputFolder(inDir).isEmpty)
}
