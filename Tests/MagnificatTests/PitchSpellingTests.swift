import Testing
@testable import Magnificat

// SPEC.md §6.2 — "Step letter, then accidental word if any, then octave number".

@Test func spellsAnUnalteredPitchAsLetterThenOctave() {
    #expect(Pitch(step: .c, alter: 0, octave: 5).spokenName == "C 5")
    #expect(Pitch(step: .a, alter: 0, octave: 4).spokenName == "A 4")
    #expect(Pitch(step: .g, alter: 0, octave: 2).spokenName == "G 2")
}

@Test func spellsSingleAccidentalsAsWords() {
    #expect(Pitch(step: .a, alter: -1, octave: 4).spokenName == "A flat 4")
    #expect(Pitch(step: .f, alter: 1, octave: 3).spokenName == "F sharp 3")
}

@Test func spellsDoubleAccidentalsAsWords() {
    #expect(Pitch(step: .b, alter: -2, octave: 2).spokenName == "B double flat 2")
    #expect(Pitch(step: .c, alter: 2, octave: 6).spokenName == "C double sharp 6")
}
