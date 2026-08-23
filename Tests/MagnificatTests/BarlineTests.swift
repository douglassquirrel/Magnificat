import Foundation
import Testing
@testable import Magnificat

// SPEC.md §6.12 — repeats, endings and barlines. A sighted player sees these as
// shapes at the edge of a system; a reader has to be told, and told where to
// jump back to.

@Test func announcesAPickupMeasure() throws {
    let xml = scoreXML(parts: """
      <part id="P1"><measure number="0" implicit="yes">
        <attributes><divisions>4</divisions></attributes>
        <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration>
          <type>quarter</type></note>
      </measure></part>
    """)
    #expect(try measureLines(xml) == ["Measure 0. Pickup measure. C 5, quarter."])
}

@Test func namesDoubleAndFinalBarlines() throws {
    let xml = scoreXML(parts: """
      <part id="P1">
      <measure number="1"><attributes><divisions>4</divisions></attributes>
        <note><rest/><duration>4</duration><type>quarter</type></note>
        <barline location="right"><bar-style>light-light</bar-style></barline>
      </measure>
      <measure number="2">
        <note><rest/><duration>4</duration><type>quarter</type></note>
        <barline location="right"><bar-style>light-heavy</bar-style></barline>
      </measure></part>
    """)
    #expect(try measureLines(xml) == ["Measure 1. Quarter rest. Double barline.",
                                      "Measure 2. Quarter rest. Final barline."])
}

@Test func tellsTheReaderWhereARepeatJumpsBackTo() throws {
    // A backward repeat says only "go back"; which measure is the reader's
    // problem unless the transcript resolves it.
    let xml = scoreXML(parts: """
      <part id="P1">
      <measure number="1"><attributes><divisions>4</divisions></attributes>
        <note><rest/><duration>4</duration><type>quarter</type></note></measure>
      <measure number="2">
        <barline location="left"><repeat direction="forward"/></barline>
        <note><rest/><duration>4</duration><type>quarter</type></note></measure>
      <measure number="3">
        <note><rest/><duration>4</duration><type>quarter</type></note>
        <barline location="right"><repeat direction="backward"/></barline></measure>
      </part>
    """)
    #expect(try measureLines(xml) == [
        "Measure 1. Quarter rest.",
        "Measure 2. Repeat: forward repeat begins here. Quarter rest.",
        "Measure 3. Quarter rest. Repeat: go back to the start of measure 2.",
    ])
}

@Test func aRepeatWithNoForwardMarkGoesBackToTheStart() throws {
    let xml = scoreXML(parts: """
      <part id="P1">
      <measure number="1"><attributes><divisions>4</divisions></attributes>
        <note><rest/><duration>4</duration><type>quarter</type></note>
        <barline location="right"><repeat direction="backward"/></barline></measure>
      </part>
    """)
    #expect(try measureLines(xml)
            == ["Measure 1. Quarter rest. Repeat: go back to the start of measure 1."])
}

@Test func namesFirstAndSecondEndings() throws {
    let xml = scoreXML(parts: """
      <part id="P1">
      <measure number="1"><attributes><divisions>4</divisions></attributes>
        <barline location="left"><ending number="1" type="start"/></barline>
        <note><rest/><duration>4</duration><type>quarter</type></note>
        <barline location="right"><ending number="1" type="stop"/></barline></measure>
      <measure number="2">
        <barline location="left"><ending number="2" type="start"/></barline>
        <note><rest/><duration>4</duration><type>quarter</type></note></measure>
      </part>
    """)
    #expect(try measureLines(xml) == [
        "Measure 1. First ending begins. Quarter rest. Ending finishes.",
        "Measure 2. Second ending begins. Quarter rest.",
    ])
}
