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
