import Foundation
import Testing
@testable import Magnificat

// SPEC.md §6.11 — a syllable is attached to its note, hyphenated per <syllabic>
// so a reader knows whether the word continues. SPEC §6.1 forbids quotation
// marks around lyrics: many screen readers announce them.

func lyricNote(_ lyric: String) -> Data {
    scoreXML(parts: measureXML("""
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration>
        <type>quarter</type>\(lyric)</note>
    """))
}

@Test func aWholeWordSyllableTakesNoHyphens() throws {
    let xml = lyricNote("<lyric number=\"1\"><syllabic>single</syllabic><text>Du</text></lyric>")
    #expect(try measureLines(xml) == ["Measure 1. C 5, quarter, lyric Du."])
}

@Test func theFirstSyllableOfAWordTakesATrailingHyphen() throws {
    let xml = lyricNote("<lyric number=\"1\"><syllabic>begin</syllabic><text>Blu</text></lyric>")
    #expect(try measureLines(xml) == ["Measure 1. C 5, quarter, lyric Blu-."])
}

@Test func theLastSyllableOfAWordTakesALeadingHyphen() throws {
    let xml = lyricNote("<lyric number=\"1\"><syllabic>end</syllabic><text>me</text></lyric>")
    #expect(try measureLines(xml) == ["Measure 1. C 5, quarter, lyric -me."])
}

@Test func aMiddleSyllableTakesHyphensBothSides() throws {
    let xml = lyricNote("<lyric number=\"1\"><syllabic>middle</syllabic><text>ge</text></lyric>")
    #expect(try measureLines(xml) == ["Measure 1. C 5, quarter, lyric -ge-."])
}

@Test func versesBeyondTheFirstAreNumbered() throws {
    let xml = lyricNote("""
      <lyric number="1"><syllabic>single</syllabic><text>Du</text></lyric>
      <lyric number="2"><syllabic>single</syllabic><text>Sie</text></lyric>
    """)
    #expect(try measureLines(xml)
            == ["Measure 1. C 5, quarter, lyric Du, verse 2 lyric Sie."])
}

@Test func lyricTextPassesThroughUnchangedIncludingNonASCII() throws {
    // SPEC §6.1: lyrics are the one place non-ASCII may appear, and they are
    // passed through byte for byte with no normalisation.
    let xml = lyricNote("<lyric number=\"1\"><syllabic>single</syllabic><text>Blüthe</text></lyric>")
    #expect(try measureLines(xml) == ["Measure 1. C 5, quarter, lyric Blüthe."])
}

@Test func aNoteWithNoLyricSaysNothingAboutLyrics() throws {
    let xml = lyricNote("")
    #expect(try measureLines(xml) == ["Measure 1. C 5, quarter."])
}

// SPEC.md §6.11 — after each part that has lyrics, the verses are given again as
// continuous running text, so the words can be read as words rather than as one
// syllable per note.

@Test func givesEachVerseAgainAsRunningText() throws {
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>2</duration>
        <type>eighth</type>
        <lyric number="1"><syllabic>begin</syllabic><text>Blu</text></lyric></note>
      <note><pitch><step>D</step><octave>5</octave></pitch><duration>2</duration>
        <type>eighth</type>
        <lyric number="1"><syllabic>end</syllabic><text>me</text></lyric></note>
      <note><pitch><step>E</step><octave>5</octave></pitch><duration>2</duration>
        <type>eighth</type>
        <lyric number="1"><syllabic>single</syllabic><text>so</text></lyric></note>
    """))
    let summary = try Score(musicXML: xml).transcript()
        .lines.filter { $0.kind == .lyricsSummary }.map(\.text)
    #expect(summary == ["Lyrics", "Verse 1: Blume so"])
}

@Test func keepsVersesApartInTheSummary() throws {
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration>
        <type>quarter</type>
        <lyric number="1"><syllabic>single</syllabic><text>Du</text></lyric>
        <lyric number="2"><syllabic>single</syllabic><text>Sie</text></lyric></note>
    """))
    let summary = try Score(musicXML: xml).transcript()
        .lines.filter { $0.kind == .lyricsSummary }.map(\.text)
    #expect(summary == ["Lyrics", "Verse 1: Du", "Verse 2: Sie"])
}

@Test func aPartWithNoLyricsGetsNoSummary() throws {
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration>
        <type>quarter</type></note>
    """))
    #expect(try Score(musicXML: xml).transcript()
        .lines.allSatisfy { $0.kind != .lyricsSummary })
}

@Test func theMayerSummaryReadsAsGermanRatherThanAsSyllables() throws {
    let summary = try mayer().lines
        .filter { $0.kind == .lyricsSummary && $0.text.hasPrefix("Verse 1") }
        .map(\.text).first
    let text = try #require(summary)
    #expect(text.hasPrefix("Verse 1: Du bist wie eine Blume so "))
    // Syllables must be rejoined, not left hyphenated.
    #expect(!text.contains("-"))
}
