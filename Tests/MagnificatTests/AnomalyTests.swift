import Foundation
import Testing
@testable import Magnificat

// SPEC.md §6.15 — musical coherence checks, which the schema cannot express and
// which map onto what a reader would actually be misled by. Reported, never
// fatal: real OMR output is routinely incoherent, and a reader whose scanned
// page produced a ragged bar still wants the transcript.

@Test func reportsAnOverfullMeasure() throws {
    // 4/4 at divisions 4 is 16; this bar holds 24. A bar containing more music
    // than its meter allows is unambiguously wrong.
    let xml = scoreXML(parts: """
      <part id="P1"><measure number="1">
        <attributes><divisions>4</divisions>
          <time><beats>4</beats><beat-type>4</beat-type></time></attributes>
        <note><pitch><step>C</step><octave>5</octave></pitch><duration>16</duration>
          <type>whole</type></note>
        <note><pitch><step>D</step><octave>5</octave></pitch><duration>8</duration>
          <type>half</type></note>
      </measure></part>
    """)
    let transcript = try Score(musicXML: xml).transcript()
    #expect(transcript.anomalies.count == 1)
    let anomaly = try #require(transcript.anomalies.first)
    #expect(anomaly.kind == .measureDurationMismatch)
    #expect(anomaly.measureNumber == "1")
    #expect(anomaly.detail.contains("24"))
    #expect(anomaly.detail.contains("16"))
    // The transcript is still produced in full.
    #expect(transcript.lines.contains { $0.kind == .measure })
}

@Test func doesNotReportAShortMeasure() throws {
    // Short bars are routine in correct music: a pickup, the bar before a repeat,
    // the bar closing a first ending. The Davies holds 12 divisions in bar 6 and
    // 4 in bar 7, which sum to a full bar across a repeat barline. Flagging short
    // bars fired on correct music, which trains a reader to ignore anomalies.
    let xml = scoreXML(parts: """
      <part id="P1"><measure number="1">
        <attributes><divisions>4</divisions>
          <time><beats>4</beats><beat-type>4</beat-type></time></attributes>
        <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration>
          <type>quarter</type></note>
      </measure></part>
    """)
    #expect(try Score(musicXML: xml).transcript().anomalies.isEmpty)
}

@Test func acceptsAMeasureThatAddsUp() throws {
    let xml = scoreXML(parts: """
      <part id="P1"><measure number="1">
        <attributes><divisions>4</divisions>
          <time><beats>4</beats><beat-type>4</beat-type></time></attributes>
        <note><pitch><step>C</step><octave>5</octave></pitch><duration>16</duration>
          <type>whole</type></note>
      </measure></part>
    """)
    #expect(try Score(musicXML: xml).transcript().anomalies.isEmpty)
}

@Test func doesNotComplainAboutAPickupMeasure() throws {
    // A pickup is short by definition; complaining would be noise on every song.
    let xml = scoreXML(parts: """
      <part id="P1"><measure number="0" implicit="yes">
        <attributes><divisions>4</divisions>
          <time><beats>4</beats><beat-type>4</beat-type></time></attributes>
        <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration>
          <type>quarter</type></note>
      </measure></part>
    """)
    #expect(try Score(musicXML: xml).transcript().anomalies.isEmpty)
}

@Test func doesNotComplainWhenThereIsNoTimeSignatureToCheckAgainst() throws {
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>7</duration>
        <type>quarter</type></note>
    """))
    #expect(try Score(musicXML: xml).transcript().anomalies
        .allSatisfy { $0.kind != .measureDurationMismatch })
}

@Test func reportsANoteOnAStaffThePartDoesNotHave() throws {
    let xml = scoreXML(parts: """
      <part id="P1"><measure number="1">
        <attributes><divisions>4</divisions><staves>2</staves></attributes>
        <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration>
          <type>quarter</type><staff>7</staff></note>
      </measure></part>
    """)
    let anomalies = try Score(musicXML: xml).transcript().anomalies
    #expect(anomalies.contains { $0.kind == .staffOutOfRange })
}

@Test func reportsADurationThatContradictsItsNotatedType() throws {
    // A "quarter" lasting 999 divisions is self-contradictory. The schema passes
    // this; it is one of the five corruptions §6.15 measured.
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>999</duration>
        <type>quarter</type></note>
    """))
    let anomalies = try Score(musicXML: xml).transcript().anomalies
    #expect(anomalies.contains { $0.kind == .durationContradictsType })
}

@Test func doesNotComplainAboutTupletsWhoseDurationIsModified() throws {
    // A triplet eighth at divisions 12 lasts 4, not 6. That is not a contradiction.
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration>
        <type>eighth</type>
        <time-modification><actual-notes>3</actual-notes>
          <normal-notes>2</normal-notes></time-modification></note>
    """, divisions: 12))
    let anomalies = try Score(musicXML: xml).transcript().anomalies
    #expect(anomalies.allSatisfy { $0.kind != .durationContradictsType })
}

@Test func aCleanScoreProducesNoAnomaliesAtAll() throws {
    // The hand-made OpenScore files are correct music; anomalies on them would
    // mean the checks are wrong, not the files.
    for name in ["mayer-1-du-bist-wie-eine-blume.musicxml",
                 "webern-5-ihr-tratet-zu-dem-herde.musicxml",
                 "davies-1-the-apology.musicxml"] {
        let transcript = try Score(musicXML: Fixture.named(name)).transcript()
        #expect(transcript.anomalies.isEmpty,
                "\(name): \(transcript.anomalies.map(\.detail).prefix(3))")
    }
}

@Test func noHandMadeFixtureReportsAnyAnomaly() throws {
    // All twelve OpenScore transcriptions are correct music. An anomaly on any of
    // them would mean the checks are wrong, not the file — which is exactly how
    // the short-measure rule was found to be wrong.
    for (name, data) in Fixture.all where name.hasSuffix(".musicxml") {
        guard Bundle.module.url(forResource: "Fixtures", withExtension: nil)
            .map({ FileManager.default.fileExists(
                atPath: $0.appendingPathComponent("openscore/\(name)").path) }) == true
        else { continue }
        let transcript = try Score(musicXML: data).transcript()
        #expect(transcript.anomalies.isEmpty,
                "\(name): \(transcript.anomalies.prefix(2).map(\.detail))")
    }
}
