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
        "Key: A flat major, 4 flats",
        "Time signature: 4 4",
    ])
}

@Test func namesEveryKeySignature() throws {
    let expected: [Int: String] = [
        0: "C major, no sharps or flats", -1: "F major, 1 flat",
        -4: "A flat major, 4 flats", -7: "C flat major, 7 flats",
        1: "G major, 1 sharp", 4: "E major, 4 sharps", 7: "C sharp major, 7 sharps",
    ]
    for (fifths, name) in expected.sorted(by: { $0.key < $1.key }) {
        #expect(KeySignature(fifths: fifths).spokenName == name)
    }
}

@Test func namesAMinorKeyWhenTheFileStatesTheMode() throws {
    #expect(KeySignature(fifths: 1, mode: "minor").spokenName == "E minor, 1 sharp")
    #expect(KeySignature(fifths: 0, mode: "minor").spokenName == "A minor, no sharps or flats")
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
