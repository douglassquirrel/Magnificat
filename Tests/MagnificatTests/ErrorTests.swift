import Foundation
import Testing
@testable import Magnificat

// SPEC.md §6.16 — every case is provoked by at least one test.

@Test func refusesATimewiseScore() throws {
    let xml = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <score-timewise version="4.0"><part-list/></score-timewise>
    """.utf8)
    #expect(throws: TranscriptionError.unsupportedRootElement(found: "score-timewise")) {
        _ = try Score(musicXML: xml)
    }
}

@Test func refusesADocumentThatIsNotAScoreAtAll() {
    let xml = Data("<?xml version=\"1.0\"?><html><body>not music</body></html>".utf8)
    #expect(throws: TranscriptionError.unsupportedRootElement(found: "html")) {
        _ = try Score(musicXML: xml)
    }
}

@Test func reportsMalformedXMLWithItsPosition() throws {
    let xml = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0">
      <part-list></part-lst>
    </score-partwise>
    """.utf8)
    let error = #expect(throws: TranscriptionError.self) {
        _ = try Score(musicXML: xml)
    }
    guard case .malformedXML(let line, _) = try #require(error) else {
        Issue.record("expected malformedXML, got \(String(describing: error))")
        return
    }
    #expect(line > 0)
}

@Test func reportsACorruptedArchiveRatherThanParsingItAsGarbage() throws {
    // Compressed .mxl is now read (CompressedMusicXMLTests.swift covers the
    // real round trip against real fixtures) — this provokes the archive
    // itself being broken, not the MusicXML inside it. The ZIP signature is
    // real; nothing after it is a valid archive.
    var data = Data([0x50, 0x4B, 0x03, 0x04])   // "PK\u{03}\u{04}"
    data.append(Data(repeating: 0, count: 32))
    let error = #expect(throws: TranscriptionError.self) {
        _ = try Score(musicXML: data)
    }
    guard case .corruptedArchive = try #require(error) else {
        Issue.record("expected .corruptedArchive, got \(String(describing: error))")
        return
    }
}

@Test func refusesAScoreWithNoPartsAtAll() {
    let xml = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0"><part-list></part-list></score-partwise>
    """.utf8)
    #expect(throws: TranscriptionError.emptyScore) { _ = try Score(musicXML: xml) }
}

@Test func refusesAScoreWhosePartsHoldNoMeasures() {
    let xml = scoreXML(parts: "<part id=\"P1\"></part>")
    #expect(throws: TranscriptionError.emptyScore) { _ = try Score(musicXML: xml) }
}

@Test func reportsAnOctaveThatIsNotANumber() {
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>C</step><octave>banana</octave></pitch>
        <duration>4</duration><type>whole</type></note>
    """))
    #expect(throws: TranscriptionError.invalidValue(element: "octave", value: "banana")) {
        _ = try Score(musicXML: xml)
    }
}

@Test func reportsAStepThatIsNotANoteName() {
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>H</step><octave>4</octave></pitch>
        <duration>4</duration><type>whole</type></note>
    """))
    #expect(throws: TranscriptionError.invalidValue(element: "step", value: "H")) {
        _ = try Score(musicXML: xml)
    }
}
