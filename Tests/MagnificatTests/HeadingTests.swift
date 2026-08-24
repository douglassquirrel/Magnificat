import Foundation
import Testing
@testable import Magnificat

// SPEC.md §6.13 — the heading block, one fact per line, omitting what the file
// does not carry. Metadata is reflected exactly as written, never edited.

func headingLines(_ xml: Data) throws -> [String] {
    try Score(musicXML: xml).transcript()
        .lines.filter { $0.kind == .scoreHeading }.map(\.text)
}

@Test func spec7point5_theMayerHeading() throws {
    let transcript = try mayer()
    #expect(transcript.lines.filter { $0.kind == .scoreHeading }.map(\.text) == [
        "Du bist wie eine Blume",
        "Emilie Mayer",
        "Words by Heinrich Heine",
        "From 3 Lieder, Op.7, number 1",
        "2 parts: Singstimme, Voice; Pianoforte",
        "32 measures",
        // Not "A flat major": the Mayer states no <mode>, and naming the key
        // from four flats alone would be a guess. The altered notes are facts.
        "Key signature: 4 flats, B flat, E flat, A flat, D flat",
        "Time signature: 4 4",
    ])
}

// These two expectations were written when the heading named a major key from
// the accidental count alone. That was a guess, and it is gone: a name is given
// only when the file states a <mode>. The tonic tables are still exercised, now
// through a stated mode.

@Test func namesEveryMajorKeyWhenTheModeIsStated() throws {
    let expected: [Int: String] = [
        0: "C major, no sharps or flats",
        -1: "F major, 1 flat, B flat",
        -4: "A flat major, 4 flats, B flat, E flat, A flat, D flat",
        1: "G major, 1 sharp, F sharp",
        4: "E major, 4 sharps, F sharp, C sharp, G sharp, D sharp",
    ]
    for (fifths, name) in expected.sorted(by: { $0.key < $1.key }) {
        #expect(KeySignature(fifths: fifths, mode: "major").spokenName == name)
    }
}

@Test func namesTheExtremeKeysWhenTheModeIsStated() throws {
    #expect(KeySignature(fifths: -7, mode: "major").spokenName
            == "C flat major, 7 flats, B flat, E flat, A flat, D flat, G flat, C flat, F flat")
    #expect(KeySignature(fifths: 7, mode: "major").spokenName
            == "C sharp major, 7 sharps, F sharp, C sharp, G sharp, D sharp, A sharp, "
             + "E sharp, B sharp")
}

@Test func saysSoWhenAScoreHasNoTimeSignature() throws {
    // SPEC §6.13 and §7.6 — the Parry has no <time> anywhere, and its absence is
    // information, so the line is present rather than omitted.
    let score = try Score(musicXML: Fixture.named("parry-2-good-night.musicxml"))
    let heading = score.transcript().lines.filter { $0.kind == .scoreHeading }.map(\.text)
    #expect(heading.contains("No time signature."))
    #expect(!heading.contains { $0.hasPrefix("Time signature:") })
}

@Test func omitsFactsTheFileDoesNotCarry() throws {
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration>
        <type>quarter</type></note>
    """))
    // No title, composer, lyricist, key or meter in this document.
    #expect(try headingLines(xml) == ["1 part: Voice", "1 measure", "No time signature."])
}

@Test func reflectsOddMetadataRatherThanTidyingIt() throws {
    // One OMR fixture has a part named after the model that produced it.
    let score = try Score(musicXML: Fixture.named("organ-noordt-modern-engraving.zeus.musicxml"))
    let heading = score.transcript().lines.filter { $0.kind == .scoreHeading }.map(\.text)
    #expect(heading.contains { $0.contains("Zeus") })
}

// SPEC.md §6.13, revised 24 August 2026: name the key only when the file names
// it. MusicXML gives <mode> on just 3 of the 92 <key> elements in the fixtures,
// and two of those are <mode>none</mode> on the Webern — the file saying outright
// that the music has no key, which the old rule overrode with "C major".

@Test func namesTheKeyWhenTheFileStatesItsMode() throws {
    #expect(KeySignature(fifths: 1, mode: "minor").spokenName == "E minor, 1 sharp, F sharp")
    #expect(KeySignature(fifths: -4, mode: "major").spokenName
            == "A flat major, 4 flats, B flat, E flat, A flat, D flat")
    #expect(KeySignature(fifths: 0, mode: "minor").spokenName
            == "A minor, no sharps or flats")
}

@Test func statesOnlyTheAccidentalsWhenTheFileNamesNoMode() throws {
    // No tonic is asserted. The altered notes are facts and are worth more to a
    // player than a guessed name.
    #expect(KeySignature(fifths: -4).spokenName == "4 flats, B flat, E flat, A flat, D flat")
    #expect(KeySignature(fifths: 1).spokenName == "1 sharp, F sharp")
    #expect(KeySignature(fifths: 0).spokenName == "no sharps or flats")
    #expect(KeySignature(fifths: 7).spokenName
            == "7 sharps, F sharp, C sharp, G sharp, D sharp, A sharp, E sharp, B sharp")
}

@Test func namesAModeWithoutGuessingItsTonic() throws {
    // Working out the tonic of a mode from the accidental count needs a table per
    // mode. The file said "dorian" and that is what is said back.
    #expect(KeySignature(fifths: 0, mode: "dorian").spokenName
            == "dorian, no sharps or flats")
}

@Test func saysAScoreHasNoKeyWhenTheFileSaysSo() throws {
    // The Webern writes <mode>none</mode>: atonal, and it says so.
    let score = try Score(musicXML: Fixture.named("webern-5-ihr-tratet-zu-dem-herde.musicxml"))
    let heading = score.transcript().lines.filter { $0.kind == .scoreHeading }.map(\.text)
    #expect(heading.contains("No key signature."))
    #expect(!heading.contains { $0.contains("C major") })
}

@Test func theMayerHeadingNoLongerGuessesAMajorKey() throws {
    // The Mayer states no mode. It is in A flat major, and every musician can
    // hear that, but the file does not say so and neither does the transcript.
    let heading = try mayer().lines.filter { $0.kind == .scoreHeading }.map(\.text)
    #expect(heading.contains("Key signature: 4 flats, B flat, E flat, A flat, D flat"))
    #expect(!heading.contains { $0.contains("major") })
}
