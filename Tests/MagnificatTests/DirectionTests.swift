import Foundation
import Testing
@testable import Magnificat

// SPEC.md §6.9 — dynamics are always prefixed. A bare "Piano" at the start of a
// line is ambiguous between the instrument and the dynamic, which is exactly the
// quiet wrongness this library exists to avoid.

func directionMeasure(_ direction: String) -> Data {
    scoreXML(parts: measureXML("""
      \(direction)
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration>
        <type>quarter</type></note>
    """))
}

@Test func prefixesEveryDynamicSoItIsNeverMistakenForAnInstrument() throws {
    let xml = directionMeasure("""
      <direction placement="below"><direction-type><dynamics><p/></dynamics>
        </direction-type></direction>
    """)
    #expect(try measureLines(xml) == ["Measure 1. Dynamic: piano. C 5, quarter."])
}

@Test func spellsTheCommonDynamicsAsWords() throws {
    let cases = [("pp", "pianissimo"), ("p", "piano"), ("mp", "mezzo piano"),
                 ("mf", "mezzo forte"), ("f", "forte"), ("ff", "fortissimo"),
                 ("fff", "triple forte"), ("ppp", "triple piano"),
                 ("sf", "sforzando"), ("fp", "forte piano")]
    for (mark, word) in cases {
        let xml = directionMeasure("""
          <direction><direction-type><dynamics><\(mark)/></dynamics>
            </direction-type></direction>
        """)
        #expect(try measureLines(xml).first?.contains("Dynamic: \(word).") == true,
                "\(mark) should be spoken as \(word)")
    }
}

@Test func passesTextDirectionsThroughAsWritten() throws {
    let xml = directionMeasure("""
      <direction placement="above"><direction-type>
        <words font-weight="bold">Un poco Adagio</words></direction-type>
        <sound tempo="71"/></direction>
    """)
    // <sound> is playback data, not notation, and is ignored: SPEC §6.9.
    #expect(try measureLines(xml) == ["Measure 1. Un poco Adagio. C 5, quarter."])
}

@Test func aDirectionComesBeforeTheNoteItPrecedes() throws {
    let xml = scoreXML(parts: measureXML("""
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration>
        <type>quarter</type></note>
      <direction><direction-type><dynamics><f/></dynamics></direction-type></direction>
      <note><pitch><step>D</step><octave>5</octave></pitch><duration>4</duration>
        <type>quarter</type></note>
    """))
    #expect(try measureLines(xml)
            == ["Measure 1. C 5, quarter. Dynamic: forte. D 5, quarter."])
}

// SPEC.md §6.9 — the rest of the directions. Each says what it is and whether it
// begins or ends: a reader has no shape on the page to see it from.

@Test func namesHairpinsByTheDirectionTheyGoIn() throws {
    let start = directionMeasure("""
      <direction><direction-type><wedge type="crescendo"/></direction-type></direction>
    """)
    #expect(try measureLines(start).first?.contains("Crescendo begins.") == true)

    let diminuendo = directionMeasure("""
      <direction><direction-type><wedge type="diminuendo"/></direction-type></direction>
    """)
    #expect(try measureLines(diminuendo).first?.contains("Diminuendo begins.") == true)
}

@Test func aWedgeStopNamesTheWedgeItEnds() throws {
    // <wedge type="stop"/> does not say which hairpin it closes; the renderer has
    // to remember. Saying only "Hairpin ends" would leave a reader guessing.
    let xml = scoreXML(parts: measureXML("""
      <direction><direction-type><wedge type="crescendo"/></direction-type></direction>
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration>
        <type>quarter</type></note>
      <direction><direction-type><wedge type="stop"/></direction-type></direction>
    """))
    #expect(try measureLines(xml)
            == ["Measure 1. Crescendo begins. C 5, quarter. Crescendo ends."])
}

@Test func namesPedalAndOctaveShiftAndRehearsalMarks() throws {
    let cases = [
        ("<pedal type=\"start\"/>", "Pedal down."),
        ("<pedal type=\"stop\"/>", "Pedal up."),
        ("<octave-shift type=\"down\" size=\"8\"/>", "Octave shift down begins."),
        ("<octave-shift type=\"stop\" size=\"8\"/>", "Octave shift ends."),
        ("<rehearsal>A</rehearsal>", "Rehearsal mark A."),
    ]
    for (element, expected) in cases {
        let xml = directionMeasure("<direction><direction-type>\(element)"
                                   + "</direction-type></direction>")
        #expect(try measureLines(xml).first?.contains(expected) == true,
                "\(element) should give \(expected)")
    }
}

@Test func readsAMetronomeMarkAsATempo() throws {
    let xml = directionMeasure("""
      <direction><direction-type><metronome>
        <beat-unit>quarter</beat-unit><per-minute>71</per-minute>
      </metronome></direction-type></direction>
    """)
    #expect(try measureLines(xml).first?.contains("Tempo: quarter note equals 71.") == true)
}

@Test func readsADottedMetronomeMark() throws {
    let xml = directionMeasure("""
      <direction><direction-type><metronome>
        <beat-unit>quarter</beat-unit><beat-unit-dot/><per-minute>60</per-minute>
      </metronome></direction-type></direction>
    """)
    #expect(try measureLines(xml).first?
            .contains("Tempo: dotted quarter note equals 60.") == true)
}
