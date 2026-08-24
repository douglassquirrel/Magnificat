import Foundation
import Testing
@testable import Magnificat

// SPEC.md §5 — the public surface: a summary for a file picker, subsetting for
// practice, and a one-call convenience.

@Test func summarisesAScoreWithoutRenderingIt() throws {
    let score = try Score(musicXML: Fixture.named("mayer-1-du-bist-wie-eine-blume.musicxml"))
    let summary = score.summary
    #expect(summary.title == "Du bist wie eine Blume")
    #expect(summary.composer == "Emilie Mayer")
    #expect(summary.lyricist == "Heinrich Heine")
    #expect(summary.partNames == ["Singstimme, Voice", "Pianoforte"])
    #expect(summary.measureCount == 32)
    #expect(summary.key == KeySignature(fifths: -4))
    #expect(summary.time == TimeSignature(beats: 4, beatType: 4))
    #expect(summary.hasLyrics)
    #expect(summary.verseCount == 1)
}

@Test func summarisesAScoreWithNoLyricsOrMeter() throws {
    let score = try Score(musicXML: Fixture.named("parry-2-good-night.musicxml"))
    #expect(score.summary.time == nil)
    #expect(score.summary.hasLyrics)
}

@Test func restrictsATranscriptToOnePartByPosition() throws {
    // Position, not name: OMR output gives parts blank names and hash IDs.
    let score = try Score(musicXML: Fixture.named("mayer-1-du-bist-wie-eine-blume.musicxml"))
    let transcript = try score.transcript(parts: [.index(1)])
    #expect(transcript.lines.allSatisfy { $0.partID == nil || $0.partID == "P1" })
    #expect(transcript.lines.contains { $0.partID == "P1" })
}

@Test func restrictsATranscriptToOnePartByName() throws {
    let score = try Score(musicXML: Fixture.named("mayer-1-du-bist-wie-eine-blume.musicxml"))
    let transcript = try score.transcript(parts: [.named("Pianoforte")])
    #expect(transcript.lines.allSatisfy { $0.partID == nil || $0.partID == "P2" })
}

@Test func restrictsATranscriptToAMeasureRange() throws {
    let score = try Score(musicXML: Fixture.named("mayer-1-du-bist-wie-eine-blume.musicxml"))
    let transcript = try score.transcript(measures: 4...5)
    let numbers = Set(transcript.lines.compactMap(\.measureNumber))
    #expect(numbers == ["4", "5"])
}

@Test func refusesAPartThatIsNotInTheScore() throws {
    let score = try Score(musicXML: Fixture.named("mayer-1-du-bist-wie-eine-blume.musicxml"))
    #expect(throws: TranscriptionError.unknownPart("Trombone")) {
        _ = try score.transcript(parts: [.named("Trombone")])
    }
    #expect(throws: TranscriptionError.unknownPart("9")) {
        _ = try score.transcript(parts: [.index(9)])
    }
}

@Test func refusesAMeasureRangeTheScoreDoesNotHave() throws {
    let score = try Score(musicXML: Fixture.named("mayer-1-du-bist-wie-eine-blume.musicxml"))
    #expect(throws: TranscriptionError.measureRangeOutOfBounds(requested: 90...100,
                                                              available: 1...32)) {
        _ = try score.transcript(measures: 90...100)
    }
}

@Test func theOneCallConvenienceMatchesTheLongWay() throws {
    let data = try Fixture.named("mayer-1-du-bist-wie-eine-blume.musicxml")
    let direct = try transcribe(musicXML: data)
    let long = try Score(musicXML: data).transcript().plainText
    #expect(direct == long)
}

@Test func plainTextEndsWithExactlyOneNewline() throws {
    let text = try transcribe(musicXML: Fixture.named("parry-2-good-night.musicxml"))
    #expect(text.hasSuffix("\n"))
    #expect(!text.hasSuffix("\n\n"))
    #expect(!text.contains("\r"))
}

// Found while writing the README: restricting to bars 4 to 5 lost the key and
// meter, because MusicXML states them once in measure 1 and the filter dropped
// it. The heading then said "No time signature", and the accidental rules lost
// the key signature they depend on.

@Test func aMeasureRangeKeepsTheAttributesInForceWhenItStarts() throws {
    let score = try Score(musicXML: Fixture.named("mayer-1-du-bist-wie-eine-blume.musicxml"))
    let transcript = try score.transcript(measures: 5...6)
    let heading = transcript.lines.filter { $0.kind == .scoreHeading }.map(\.text)
    #expect(heading.contains("Key signature: 4 flats, B flat, E flat, A flat, D flat"))
    #expect(heading.contains("Time signature: 4 4"))
    #expect(!heading.contains("No time signature."))
}

@Test func aMeasureRangeCarriesTheKeyIntoThePitchNames() throws {
    // In A flat major the A of bar 5 must read "A natural 4". Without the key it
    // would read "A 4" — a different note, told to a reader who cannot check.
    let score = try Score(musicXML: Fixture.named("mayer-1-du-bist-wie-eine-blume.musicxml"))
    let full = try score.transcript(parts: [.index(1)], measures: 5...5)
    #expect(full.lines.contains { $0.text.contains("A natural 4") })
}

@Test func aMeasureRangeStartingMidPieceUsesTheLatestAttributes() throws {
    // Where a score restates its meter, the range must pick up the restatement
    // rather than the opening one.
    let xml = scoreXML(parts: """
      <part id="P1">
        <measure number="1"><attributes><divisions>4</divisions>
          <key><fifths>0</fifths></key>
          <time><beats>4</beats><beat-type>4</beat-type></time></attributes>
          <note><rest/><duration>16</duration></note></measure>
        <measure number="2"><attributes>
          <key><fifths>-2</fifths></key>
          <time><beats>3</beats><beat-type>4</beat-type></time></attributes>
          <note><rest/><duration>12</duration></note></measure>
        <measure number="3"><note><rest/><duration>12</duration></note></measure>
      </part>
    """)
    let heading = try Score(musicXML: xml).transcript(measures: 3...3)
        .lines.filter { $0.kind == .scoreHeading }.map(\.text)
    // The document states no <mode>, so no key is named — only its accidentals.
    #expect(heading.contains("Key signature: 2 flats, B flat, E flat"))
    #expect(heading.contains("Time signature: 3 4"))
}
