import Foundation
import Testing
@testable import Magnificat

// SPEC.md §6.10 — notations are appended to the note in a fixed order: tie, slur,
// articulations, ornament, arpeggio, fermata, then lyrics. A reader has no shape
// on the page to see any of this from, so each says plainly what it is.

func notatedNote(_ inner: String) -> Data {
    scoreXML(parts: measureXML("""
      <note><pitch><step>A</step><alter>-1</alter><octave>4</octave></pitch>
        <duration>6</duration><type>quarter</type><dot/>\(inner)</note>
    """))
}

@Test func saysWhenANoteIsTiedAndWhenItContinuesATie() throws {
    let start = notatedNote("<tie type=\"start\"/>")
    #expect(try measureLines(start) == ["Measure 1. A flat 4, dotted quarter, tied."])

    // The continuation is still spoken: a reader needs to know a sound is
    // still going, not that a new one started.
    let stop = notatedNote("<tie type=\"stop\"/>")
    #expect(try measureLines(stop)
            == ["Measure 1. A flat 4, dotted quarter, tied from previous."])
}

@Test func aNoteThatEndsAndStartsATieSaysBoth() throws {
    let both = notatedNote("<tie type=\"stop\"/><tie type=\"start\"/>")
    #expect(try measureLines(both)
            == ["Measure 1. A flat 4, dotted quarter, tied from previous, tied."])
}

@Test func saysWhereSlursBeginAndEnd() throws {
    let begin = notatedNote("<notations><slur type=\"start\" number=\"1\"/></notations>")
    #expect(try measureLines(begin) == ["Measure 1. A flat 4, dotted quarter, slur begins."])

    let end = notatedNote("<notations><slur type=\"stop\" number=\"1\"/></notations>")
    #expect(try measureLines(end) == ["Measure 1. A flat 4, dotted quarter, slur ends."])
}

@Test func namesEveryArticulation() throws {
    let cases = [("staccato", "staccato"), ("staccatissimo", "staccatissimo"),
                 ("accent", "accent"), ("tenuto", "tenuto"),
                 ("strong-accent", "marcato"), ("breath-mark", "breath mark")]
    for (element, word) in cases {
        let xml = notatedNote("<notations><articulations><\(element)/>"
                              + "</articulations></notations>")
        #expect(try measureLines(xml)
                == ["Measure 1. A flat 4, dotted quarter, \(word)."], "\(element)")
    }
}

@Test func namesOrnamentsWithoutRealisingThem() throws {
    // SPEC §6.10: ornaments are named, never turned into notes.
    let cases = [("trill-mark", "trill"), ("mordent", "mordent"),
                 ("inverted-mordent", "inverted mordent")]
    for (element, word) in cases {
        let xml = notatedNote("<notations><ornaments><\(element)/></ornaments></notations>")
        #expect(try measureLines(xml)
                == ["Measure 1. A flat 4, dotted quarter, \(word)."], "\(element)")
    }
}

@Test func namesArpeggiosAndFermatas() throws {
    let arpeggio = notatedNote("<notations><arpeggiate/></notations>")
    #expect(try measureLines(arpeggio)
            == ["Measure 1. A flat 4, dotted quarter, arpeggiated."])

    let fermata = notatedNote("<notations><fermata type=\"upright\"/></notations>")
    #expect(try measureLines(fermata) == ["Measure 1. A flat 4, dotted quarter, fermata."])
}

@Test func keepsNotationsInTheOrderTheSpecFixes() throws {
    let xml = notatedNote("""
      <tie type="start"/>
      <notations><slur type="start"/><articulations><staccato/></articulations>
        <ornaments><trill-mark/></ornaments><arpeggiate/>
        <fermata/></notations>
      <lyric number="1"><syllabic>single</syllabic><text>ah</text></lyric>
    """)
    #expect(try measureLines(xml) == ["Measure 1. A flat 4, dotted quarter, tied, "
                                      + "slur begins, staccato, trill, arpeggiated, "
                                      + "fermata, lyric ah."])
}

@Test func prefixesGraceAndCueNotesRatherThanSuffixingThem() throws {
    let grace = scoreXML(parts: measureXML("""
      <note><grace/><pitch><step>B</step><alter>-1</alter><octave>4</octave></pitch>
        <type>eighth</type></note>
    """))
    #expect(try measureLines(grace) == ["Measure 1. Grace note: B flat 4, eighth."])

    let cue = scoreXML(parts: measureXML("""
      <note><cue/><pitch><step>B</step><alter>-1</alter><octave>4</octave></pitch>
        <duration>4</duration><type>quarter</type></note>
    """))
    #expect(try measureLines(cue) == ["Measure 1. Cue note: B flat 4, quarter."])
}
