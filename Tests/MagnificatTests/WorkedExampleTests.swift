import Foundation
import Testing
@testable import Magnificat

// SPEC.md §7 — the worked examples, verbatim. These were verified against the
// source XML by hand before the renderer existed, so they are ground truth for
// the whole pipeline: parse a real file, render it, compare to the spec.

func mayer(_ options: TranscriptOptions = TranscriptOptions()) throws -> Transcript {
    try Score(musicXML: Fixture.named("mayer-1-du-bist-wie-eine-blume.musicxml"))
        .transcript(options: options)
}

func lines(_ transcript: Transcript, partID: String, measures: [String],
           kind: TranscriptLine.Kind = .measure) -> [String] {
    transcript.lines.filter {
        $0.kind == kind && $0.partID == partID
            && measures.contains($0.measureNumber ?? "")
    }.map(\.text)
}

@Test func spec7point1_voicePartMeasures4to6() throws {
    #expect(lines(try mayer(), partID: "P1", measures: ["4", "5", "6"]) == [
        "Measure 4. Half rest. Quarter rest. Dynamic: piano. E flat 4, quarter, lyric Du.",
        "Measure 5. A flat 4, dotted quarter, lyric bist. A flat 4, eighth, lyric wie. A flat 4, quarter, lyric ei-. A natural 4, quarter, lyric -ne.",
        "Measure 6. C 5, quarter, lyric Blu-. B flat 4, quarter, lyric -me. Quarter rest. B flat 4, eighth, lyric so. A flat 4, eighth.",
    ])
}

@Test func spec7point3_theSameMeasureAsPrinted() throws {
    // Only the fourth note carries a printed accidental; the flats come from the
    // key signature and are therefore not spoken.
    let options = TranscriptOptions(accidentalStyle: .asPrinted)
    #expect(lines(try mayer(options), partID: "P1", measures: ["5"]) == [
        "Measure 5. A 4, dotted quarter, lyric bist. A 4, eighth, lyric wie. A 4, quarter, lyric ei-. A natural 4, quarter, lyric -ne.",
    ])
}

@Test func spec7point4_pianoRightHandMeasure1() throws {
    let transcript = try mayer()
    #expect(lines(transcript, partID: "P2", measures: ["1"]).first ==
        "Measure 1. Chord A flat 4, A flat 5, dotted quarter. Chord A flat 4, A flat 5, eighth. Chord A flat 4, A flat 5, quarter. Chord A natural 4, A natural 5, quarter.")
    // The stream is labelled, so a reader knows which hand they are reading.
    #expect(transcript.lines.contains {
        $0.kind == .partHeading && $0.text == "Right hand"
    })
}
