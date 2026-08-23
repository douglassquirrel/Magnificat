import Testing
@testable import Magnificat

// SPEC.md §6.6 — <voice> and <staff> default to 1. The parser supplies them
// explicitly, so these defaults are exercised here rather than left to a
// coverage report to notice they never run.

@Test func aNoteBuiltFromPitchAndDurationAloneIsOrdinary() {
    let note = Note(pitch: Pitch(step: .c, alter: 0, octave: 4),
                    duration: Duration(divisions: 4, type: .quarter))
    #expect(note.voice == 1)
    #expect(note.staff == 1)
    #expect(note.onset == 0)
    #expect(note.isChordMember == false)
    #expect(note.isGrace == false)
    #expect(note.isCue == false)
    #expect(note.isArpeggiated == false)
    #expect(note.hasFermata == false)
    #expect(note.printedAccidental == nil)
    #expect(note.lyrics.isEmpty)
    #expect(note.articulations.isEmpty)
    #expect(note.ornaments.isEmpty)
    #expect(note.tie == TieState())
    #expect(note.slur == SlurState())
}

@Test func aRestBuiltFromDurationAloneIsOrdinary() {
    let rest = Rest(duration: Duration(divisions: 4, type: .quarter),
                    isWholeMeasure: false)
    #expect(rest.voice == 1)
    #expect(rest.staff == 1)
    #expect(rest.onset == 0)
}

@Test func aDirectionDefaultsToTheFirstStaffAtTheStartOfTheMeasure() {
    let placed = PlacedDirection(direction: .dynamic("p"))
    #expect(placed.staff == 1)
    #expect(placed.onset == 0)
}

@Test func aMeasureBuiltFromANumberAloneIsEmptyAndNotAPickup() {
    let measure = Measure(number: "1")
    #expect(measure.isPickup == false)
    #expect(measure.attributes == nil)
    #expect(measure.events.isEmpty)
    #expect(measure.barlines.isEmpty)
}

@Test func aScoreBuiltFromPartsAloneHasEmptyMetadata() {
    let score = Score(parts: [Part(id: "P1", name: nil, measures: [])])
    #expect(score.metadata == ScoreMetadata())
    #expect(score.summary.title == nil)
    #expect(score.summary.partNames == ["Part 1"])
}
