import Foundation
import Testing
@testable import Magnificat

/// Wraps `body` in the smallest complete `score-partwise` document that parses.
/// Complete, not a fragment — a fragment is not XML and would test nothing.
func scoreXML(parts: String, partList: String? = nil) -> Data {
    let list = partList ?? #"<score-part id="P1"><part-name>Voice</part-name></score-part>"#
    return Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0">
      <part-list>\(list)</part-list>
      \(parts)
    </score-partwise>
    """.utf8)
}

/// A measure containing exactly `body`, with a divisions declaration.
func measureXML(_ body: String, number: String = "1", divisions: Int = 4) -> String {
    """
    <part id="P1"><measure number="\(number)">
      <attributes><divisions>\(divisions)</divisions></attributes>
      \(body)
    </measure></part>
    """
}

@Test func readsThePartListIntoNamedParts() throws {
    let score = try Score(musicXML: scoreXML(parts: measureXML("")))
    #expect(score.parts.count == 1)
    #expect(score.parts.first?.id == "P1")
    #expect(score.parts.first?.name == "Voice")
}

@Test func readsAPitchedNote() throws {
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration><type>whole</type></note>
    """))
    let score = try Score(musicXML: xml)
    let events = try #require(score.parts.first?.measures.first?.events)
    #expect(events.count == 1)
    guard case .note(let note) = events[0] else {
        Issue.record("expected a note, got \(events[0])")
        return
    }
    #expect(note.pitch == Pitch(step: .c, alter: 0, octave: 4))
    #expect(note.duration.type == .whole)
    #expect(note.duration.divisions == 4)
}

@Test func readsARestAsARestRatherThanANote() throws {
    let xml = scoreXML(parts: measureXML("""
      <note><rest/><duration>2</duration><type>half</type></note>
    """))
    let events = try #require(Score(musicXML: xml).parts.first?.measures.first?.events)
    guard case .rest(let rest) = events.first else {
        Issue.record("expected a rest, got \(String(describing: events.first))")
        return
    }
    #expect(rest.duration.type == .half)
    #expect(rest.isWholeMeasure == false)
}

@Test func readsAWholeMeasureRest() throws {
    // <rest measure="yes"/> means "a bar's rest", whatever the time signature.
    let xml = scoreXML(parts: measureXML("""
      <note><rest measure="yes"/><duration>16</duration></note>
    """))
    let events = try #require(Score(musicXML: xml).parts.first?.measures.first?.events)
    guard case .rest(let rest) = events.first else {
        Issue.record("expected a rest")
        return
    }
    #expect(rest.isWholeMeasure)
}

// SPEC.md §6.6 — <voice> and <staff> are optional in practice. In the OMR fixtures
// 3,317 of 6,494 notes carry no <voice> and 6,170 carry no <staff>; a parser that
// required either would reject most real machine output.

@Test func readsVoiceAndStaffWhenGiven() throws {
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>G</step><octave>3</octave></pitch><duration>4</duration>
        <type>whole</type><voice>2</voice><staff>2</staff></note>
    """))
    let events = try #require(Score(musicXML: xml).parts.first?.measures.first?.events)
    guard case .note(let note) = events.first else { Issue.record("expected a note"); return }
    #expect(note.voice == 2)
    #expect(note.staff == 2)
}

@Test func defaultsVoiceAndStaffToOneWhenAbsent() throws {
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>G</step><octave>3</octave></pitch><duration>4</duration>
        <type>whole</type></note>
    """))
    let events = try #require(Score(musicXML: xml).parts.first?.measures.first?.events)
    guard case .note(let note) = events.first else { Issue.record("expected a note"); return }
    #expect(note.voice == 1)
    #expect(note.staff == 1)
}

@Test func marksTheSecondAndLaterNotesOfAChord() throws {
    // MusicXML marks chord members after the first with <chord/>.
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>A</step><alter>-1</alter><octave>4</octave></pitch>
        <duration>4</duration><type>whole</type></note>
      <note><chord/><pitch><step>A</step><alter>-1</alter><octave>5</octave></pitch>
        <duration>4</duration><type>whole</type></note>
    """))
    let events = try #require(Score(musicXML: xml).parts.first?.measures.first?.events)
    #expect(events.count == 2)
    guard case .note(let first) = events[0], case .note(let second) = events[1] else {
        Issue.record("expected two notes"); return
    }
    #expect(first.isChordMember == false)
    #expect(second.isChordMember)
}

@Test func readsAugmentationDots() throws {
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>6</duration>
        <type>quarter</type><dot/></note>
    """))
    let events = try #require(Score(musicXML: xml).parts.first?.measures.first?.events)
    guard case .note(let note) = events.first else { Issue.record("expected a note"); return }
    #expect(note.duration.dots == 1)
}

@Test func readsATupletRatio() throws {
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>2</duration>
        <type>eighth</type>
        <time-modification><actual-notes>3</actual-notes>
          <normal-notes>2</normal-notes></time-modification></note>
    """))
    let events = try #require(Score(musicXML: xml).parts.first?.measures.first?.events)
    guard case .note(let note) = events.first else { Issue.record("expected a note"); return }
    #expect(note.duration.tuplet == Tuplet(actual: 3, normal: 2))
}

@Test func readsThePrintedAccidentalSeparatelyFromTheAlteration() throws {
    // The two are independent: a note may sound flat with nothing printed.
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>4</duration>
        <type>whole</type><accidental>natural</accidental></note>
    """))
    let events = try #require(Score(musicXML: xml).parts.first?.measures.first?.events)
    guard case .note(let note) = events.first else { Issue.record("expected a note"); return }
    #expect(note.printedAccidental == .natural)
    #expect(note.pitch.alter == 0)
}

// SPEC.md §6.13, §6.14 — attributes may be restated mid-piece; Ferrari restates
// the key eight times and Webern the meter twenty.

@Test func readsDivisionsKeyAndTimeFromAttributes() throws {
    let xml = scoreXML(parts: """
      <part id="P1"><measure number="1">
        <attributes><divisions>12</divisions>
          <key><fifths>-4</fifths></key>
          <time><beats>3</beats><beat-type>4</beat-type></time>
          <staves>2</staves></attributes>
      </measure></part>
    """)
    let measure = try #require(Score(musicXML: xml).parts.first?.measures.first)
    #expect(measure.attributes?.divisions == 12)
    #expect(measure.attributes?.key == KeySignature(fifths: -4))
    #expect(measure.attributes?.time == TimeSignature(beats: 3, beatType: 4))
    #expect(measure.attributes?.staves == 2)
}

@Test func aMeasureWithNoAttributesElementCarriesNone() throws {
    let xml = scoreXML(parts: "<part id=\"P1\"><measure number=\"2\"></measure></part>")
    let measure = try #require(Score(musicXML: xml).parts.first?.measures.first)
    #expect(measure.attributes == nil)
}

@Test func readsAScoreThatNeverStatesATimeSignature() throws {
    // The Parry has no <time> element anywhere. Its absence is information.
    let score = try Score(musicXML: Fixture.named("parry-2-good-night.musicxml"))
    let times = score.parts.flatMap(\.measures).compactMap { $0.attributes?.time }
    #expect(times.isEmpty)
    #expect(!score.parts.isEmpty)
}

@Test func marksAPickupMeasureAsImplicit() throws {
    let xml = scoreXML(parts: """
      <part id="P1"><measure number="0" implicit="yes"></measure>
      <measure number="1"></measure></part>
    """)
    let measures = try #require(Score(musicXML: xml).parts.first?.measures)
    #expect(measures[0].number == "0")
    #expect(measures[0].isPickup)
    #expect(measures[1].isPickup == false)
}

// SPEC.md §6.6 — <backup> and <forward> are resolved during parsing and never
// appear in the output; their only job is to place events at the right time.
// This is the mechanism a piano grand staff is written with.

@Test func backupReturnsTheCursorSoASecondVoiceStartsWhereTheFirstDid() throws {
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration>
        <type>quarter</type><voice>1</voice><staff>1</staff></note>
      <note><pitch><step>D</step><octave>5</octave></pitch><duration>4</duration>
        <type>quarter</type><voice>1</voice><staff>1</staff></note>
      <backup><duration>8</duration></backup>
      <note><pitch><step>C</step><octave>3</octave></pitch><duration>8</duration>
        <type>half</type><voice>5</voice><staff>2</staff></note>
    """))
    let events = try #require(Score(musicXML: xml).parts.first?.measures.first?.events)
    #expect(events.count == 3, "backup must not become an event of its own")
    let onsets = events.map(\.onset)
    #expect(onsets == [0, 4, 0])
}

@Test func chordMembersShareTheOnsetOfTheNoteTheySoundWith() throws {
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>4</duration>
        <type>quarter</type></note>
      <note><chord/><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration>
        <type>quarter</type></note>
      <note><pitch><step>B</step><octave>4</octave></pitch><duration>4</duration>
        <type>quarter</type></note>
    """))
    let events = try #require(Score(musicXML: xml).parts.first?.measures.first?.events)
    #expect(events.map(\.onset) == [0, 0, 4])
}

@Test func forwardSkipsTimeWithoutProducingAnEvent() throws {
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>4</duration>
        <type>quarter</type></note>
      <forward><duration>4</duration></forward>
      <note><pitch><step>B</step><octave>4</octave></pitch><duration>4</duration>
        <type>quarter</type></note>
    """))
    let events = try #require(Score(musicXML: xml).parts.first?.measures.first?.events)
    #expect(events.count == 2)
    #expect(events.map(\.onset) == [0, 8])
}

@Test func graceNotesDoNotAdvanceTheCursor() throws {
    // A grace note is ornamental and carries no duration; letting it advance the
    // cursor would push every following note out of place.
    let xml = scoreXML(parts: measureXML("""
      <note><grace/><pitch><step>B</step><octave>4</octave></pitch>
        <type>eighth</type></note>
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>4</duration>
        <type>quarter</type></note>
    """))
    let events = try #require(Score(musicXML: xml).parts.first?.measures.first?.events)
    #expect(events.map(\.onset) == [0, 0])
}
