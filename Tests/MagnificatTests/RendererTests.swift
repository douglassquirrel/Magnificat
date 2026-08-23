import Foundation
import Testing
@testable import Magnificat

/// The measure lines of a transcript, which is what most rules in §6 govern.
func measureLines(_ xml: Data, _ options: TranscriptOptions = TranscriptOptions()) throws -> [String] {
    try Score(musicXML: xml).transcript(options: options)
        .lines.filter { $0.kind == .measure }.map(\.text)
}

// SPEC.md §6.8 — at .perMeasure density, one line per measure, events separated
// by ". ", the line beginning "Measure <n>. ".

@Test func rendersAMeasureOfNotesAsOneLine() throws {
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration>
        <type>quarter</type></note>
      <note><pitch><step>B</step><alter>-1</alter><octave>4</octave></pitch>
        <duration>4</duration><type>quarter</type></note>
    """))
    #expect(try measureLines(xml) == ["Measure 1. C 5, quarter. B flat 4, quarter."])
}

@Test func rendersRestsByTheirDuration() throws {
    let xml = scoreXML(parts: measureXML("""
      <note><rest/><duration>8</duration><type>half</type></note>
      <note><rest/><duration>4</duration><type>quarter</type></note>
    """))
    #expect(try measureLines(xml) == ["Measure 1. Half rest. Quarter rest."])
}

@Test func rendersAWholeMeasureRest() throws {
    let xml = scoreXML(parts: measureXML("""
      <note><rest measure="yes"/><duration>16</duration></note>
    """))
    #expect(try measureLines(xml) == ["Measure 1. Whole measure rest."])
}

// SPEC.md §6.5 — chord members are gathered into one event and rendered low to
// high regardless of document order, so the same chord reads identically twice.

@Test func gathersAChordIntoOneEventLowToHigh() throws {
    // Written high then low; must be spoken low then high.
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>A</step><alter>-1</alter><octave>5</octave></pitch>
        <duration>6</duration><type>quarter</type><dot/></note>
      <note><chord/><pitch><step>A</step><alter>-1</alter><octave>4</octave></pitch>
        <duration>6</duration><type>quarter</type><dot/></note>
    """))
    #expect(try measureLines(xml)
            == ["Measure 1. Chord A flat 4, A flat 5, dotted quarter."])
}

@Test func ordersChordNotesWithinAnOctaveByPitchNotByLetter() throws {
    // B flat 4 sounds above F 4 even though B comes after F alphabetically only
    // by luck; the ordering must be by sounding pitch.
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>B</step><alter>-1</alter><octave>4</octave></pitch>
        <duration>4</duration><type>quarter</type></note>
      <note><chord/><pitch><step>C</step><octave>5</octave></pitch>
        <duration>4</duration><type>quarter</type></note>
      <note><chord/><pitch><step>F</step><octave>4</octave></pitch>
        <duration>4</duration><type>quarter</type></note>
    """))
    #expect(try measureLines(xml)
            == ["Measure 1. Chord F 4, B flat 4, C 5, quarter."])
}

@Test func aSingleNoteIsNotCalledAChord() throws {
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration>
        <type>quarter</type></note>
    """))
    #expect(try measureLines(xml) == ["Measure 1. C 5, quarter."])
}

// SPEC.md §6.6 — a one-staff part is one stream named for the part; a two-staff
// part is a grand staff split into hands; extra voices on a staff are their own
// streams. Blank part names fall back to position, which is the common path in
// machine-generated files rather than an edge case.

func headings(_ xml: Data) throws -> [String] {
    try Score(musicXML: xml).transcript()
        .lines.filter { $0.kind == .partHeading }.map(\.text)
}

@Test func namesASingleStaffPartAfterThePart() throws {
    #expect(try headings(scoreXML(parts: measureXML("""
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration>
        <type>quarter</type></note>
    """))) == ["Voice"])
}

@Test func fallsBackToThePartPositionWhenTheNameIsBlank() throws {
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration>
        <type>quarter</type></note>
    """), partList: #"<score-part id="P1"><part-name></part-name></score-part>"#)
    #expect(try headings(xml) == ["Part 1"])
}

@Test func splitsATwoStaffPartIntoHands() throws {
    let xml = scoreXML(parts: """
      <part id="P1"><measure number="1">
        <attributes><divisions>4</divisions><staves>2</staves></attributes>
        <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration>
          <type>quarter</type><voice>1</voice><staff>1</staff></note>
        <backup><duration>4</duration></backup>
        <note><pitch><step>C</step><octave>3</octave></pitch><duration>4</duration>
          <type>quarter</type><voice>5</voice><staff>2</staff></note>
      </measure></part>
    """, partList: #"<score-part id="P1"><part-name>Pianoforte</part-name></score-part>"#)
    #expect(try headings(xml) == ["Pianoforte", "Right hand", "Left hand"])
    // Each hand is its own stream, so each gets its own measure line.
    #expect(try measureLines(xml) == ["Measure 1. C 5, quarter.",
                                      "Measure 1. C 3, quarter."])
}

@Test func givesEachExtraVoiceOnAStaffItsOwnStream() throws {
    // Numbered by position on the staff, not by MusicXML's voice number: a piano
    // left hand uses voices 5 and 6, and "voice 6" would mean nothing to a reader.
    let xml = scoreXML(parts: """
      <part id="P1"><measure number="1">
        <attributes><divisions>4</divisions><staves>2</staves></attributes>
        <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration>
          <type>quarter</type><voice>1</voice><staff>1</staff></note>
        <backup><duration>4</duration></backup>
        <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration>
          <type>quarter</type><voice>2</voice><staff>1</staff></note>
        <backup><duration>4</duration></backup>
        <note><pitch><step>C</step><octave>3</octave></pitch><duration>4</duration>
          <type>quarter</type><voice>5</voice><staff>2</staff></note>
      </measure></part>
    """, partList: #"<score-part id="P1"><part-name>Pianoforte</part-name></score-part>"#)
    #expect(try headings(xml)
            == ["Pianoforte", "Right hand", "Right hand, voice 2", "Left hand"])
}

// SPEC.md §6.2 — "an accidental applies to that step and octave for the rest of
// the measure, across all voices and staves of that part". Streams are rendered
// one after another, so the accidental state cannot simply follow the rendering.

@Test func anAccidentalInOneHandIsInForceForTheOther() throws {
    let xml = scoreXML(parts: """
      <part id="P1"><measure number="1">
        <attributes><divisions>4</divisions><staves>2</staves></attributes>
        <note><pitch><step>C</step><alter>1</alter><octave>4</octave></pitch>
          <duration>4</duration><type>quarter</type><voice>1</voice><staff>1</staff></note>
        <backup><duration>4</duration></backup>
        <note><pitch><step>C</step><octave>4</octave></pitch>
          <duration>4</duration><type>quarter</type><voice>5</voice><staff>2</staff></note>
      </measure></part>
    """, partList: #"<score-part id="P1"><part-name>Piano</part-name></score-part>"#)
    #expect(try measureLines(xml) == ["Measure 1. C sharp 4, quarter.",
                                      "Measure 1. C natural 4, quarter."])
}

@Test func aStreamStillStartsEachMeasureWithACleanSlate() throws {
    let xml = scoreXML(parts: """
      <part id="P1">
      <measure number="1">
        <attributes><divisions>4</divisions></attributes>
        <note><pitch><step>C</step><alter>1</alter><octave>4</octave></pitch>
          <duration>4</duration><type>quarter</type></note>
      </measure>
      <measure number="2">
        <note><pitch><step>C</step><octave>4</octave></pitch>
          <duration>4</duration><type>quarter</type></note>
      </measure></part>
    """)
    #expect(try measureLines(xml) == ["Measure 1. C sharp 4, quarter.",
                                      "Measure 2. C 4, quarter."])
}

// A secondary voice usually sounds in only a few measures of a part — the Mayer's
// vocal line has seven notes in voice 2 across 32 measures. A stream must not
// emit a bare "Measure 4." for every measure it is silent in: the line would say
// nothing, and a reader stepping through would meet dozens of them.

@Test func aStreamOnlyRendersTheMeasuresItActuallySoundsIn() throws {
    let xml = scoreXML(parts: """
      <part id="P1">
      <measure number="1">
        <attributes><divisions>4</divisions></attributes>
        <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration>
          <type>quarter</type><voice>1</voice></note>
      </measure>
      <measure number="2">
        <note><pitch><step>D</step><octave>5</octave></pitch><duration>4</duration>
          <type>quarter</type><voice>1</voice></note>
        <backup><duration>4</duration></backup>
        <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration>
          <type>quarter</type><voice>2</voice></note>
      </measure></part>
    """)
    #expect(try measureLines(xml) == ["Measure 1. C 5, quarter.",
                                      "Measure 2. D 5, quarter.",
                                      "Measure 2. F 4, quarter."])
}
