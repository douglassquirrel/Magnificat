import Testing
@testable import Magnificat

// SPEC.md §6.2 — under .sounding, the accidental word reflects the pitch that sounds.
// A bare letter therefore has to mean "unaltered, and nothing in force would have
// altered it"; where the key signature would have, the word "natural" is required.

@Test func saysNaturalWhenTheKeySignatureWouldOtherwiseAlterTheStep() {
    // A flat major. The A in measure 5 of the Mayer carries a printed natural.
    var context = AccidentalContext(key: KeySignature(fifths: -4))
    #expect(context.spokenName(of: Pitch(step: .a, alter: 0, octave: 4)) == "A natural 4")
}

@Test func saysABareLetterWhenNothingWouldHaveAlteredTheStep() {
    // C is not among the four flats of A flat major, so no natural is needed.
    var context = AccidentalContext(key: KeySignature(fifths: -4))
    #expect(context.spokenName(of: Pitch(step: .c, alter: 0, octave: 5)) == "C 5")
}

@Test func spellsAnAlteredPitchByItsSoundingAlteration() {
    // E flat in A flat major carries no printed accidental; <alter> still says -1.
    var context = AccidentalContext(key: KeySignature(fifths: -4))
    #expect(context.spokenName(of: Pitch(step: .e, alter: -1, octave: 4)) == "E flat 4")
}

@Test func anAccidentalEarlierInTheMeasureMakesALaterNaturalMeaningful() {
    // No key signature, so only the C sharp already heard makes the natural needed.
    var context = AccidentalContext(key: KeySignature(fifths: 0))
    #expect(context.spokenName(of: Pitch(step: .c, alter: 1, octave: 4)) == "C sharp 4")
    #expect(context.spokenName(of: Pitch(step: .c, alter: 0, octave: 4)) == "C natural 4")
}

@Test func anAccidentalDoesNotCarryToADifferentOctave() {
    // SPEC §6.2: an accidental applies to that step *and octave*.
    var context = AccidentalContext(key: KeySignature(fifths: 0))
    #expect(context.spokenName(of: Pitch(step: .c, alter: 1, octave: 4)) == "C sharp 4")
    #expect(context.spokenName(of: Pitch(step: .c, alter: 0, octave: 5)) == "C 5")
}

@Test func aBarlineCancelsMeasureLocalAccidentalsButNotTheKey() {
    var context = AccidentalContext(key: KeySignature(fifths: -4))
    #expect(context.spokenName(of: Pitch(step: .c, alter: 1, octave: 4)) == "C sharp 4")

    context.startNewMeasure()

    // The C sharp is gone, so a plain C needs no natural...
    #expect(context.spokenName(of: Pitch(step: .c, alter: 0, octave: 4)) == "C 4")
    // ...but the four flats of A flat major survive the barline.
    #expect(context.spokenName(of: Pitch(step: .a, alter: 0, octave: 4)) == "A natural 4")
}

// SPEC.md §6.2 — under .asPrinted the accidental word appears only where the score
// prints one, and the reader applies the key signature themselves.

@Test func asPrintedSpeaksOnlyTheAccidentalsTheScorePrints() {
    var context = AccidentalContext(key: KeySignature(fifths: -4), style: .asPrinted)
    // The E flat of measure 4 sounds flat but prints nothing: the key carries it.
    #expect(context.spokenName(of: Pitch(step: .e, alter: -1, octave: 4),
                               printedAccidental: nil) == "E 4")
    // The A natural of measure 5 prints its natural.
    #expect(context.spokenName(of: Pitch(step: .a, alter: 0, octave: 4),
                               printedAccidental: .natural) == "A natural 4")
}

@Test func soundingIgnoresWhetherTheAccidentalWasPrinted() {
    var context = AccidentalContext(key: KeySignature(fifths: -4), style: .sounding)
    #expect(context.spokenName(of: Pitch(step: .e, alter: -1, octave: 4),
                               printedAccidental: nil) == "E flat 4")
}
