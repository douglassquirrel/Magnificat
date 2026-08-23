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
