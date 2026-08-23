import Testing
@testable import Magnificat

// SPEC.md §6.3 — American names only; the notated <type> is authoritative for the
// name, and <duration> in divisions is used for arithmetic and never spoken.

@Test func namesEachNotatedDurationInAmericanTerms() {
    let expected: [(NoteType, String)] = [
        (.breve, "breve"), (.whole, "whole"), (.half, "half"), (.quarter, "quarter"),
        (.eighth, "eighth"), (.sixteenth, "sixteenth"),
        (.thirtySecond, "thirty-second"), (.sixtyFourth, "sixty-fourth"),
    ]
    for (type, name) in expected {
        #expect(Duration(divisions: 1, type: type).spokenName == name)
    }
}

@Test func readsMusicXMLTypeSpellings() {
    // MusicXML writes these as "16th", "32nd", "64th" — not as words.
    #expect(NoteType(musicXML: "16th") == .sixteenth)
    #expect(NoteType(musicXML: "32nd") == .thirtySecond)
    #expect(NoteType(musicXML: "eighth") == .eighth)
    #expect(NoteType(musicXML: "wholly-invented") == nil)
}

// SPEC.md §6.3 — "Dots prefix the name". The fixtures hold 1267 single-dotted
// notes and 2 double-dotted ones; three dots is legal MusicXML and is named
// explicitly rather than silently ignored.

@Test func prefixesDottedValuesWithTheirDotCount() {
    #expect(Duration(divisions: 18, type: .quarter, dots: 1).spokenName == "dotted quarter")
    #expect(Duration(divisions: 42, type: .half, dots: 2).spokenName == "double dotted half")
    #expect(Duration(divisions: 1, type: .quarter, dots: 0).spokenName == "quarter")
}

@Test func namesUnusualDotCountsRatherThanDroppingThem() {
    #expect(Duration(divisions: 1, type: .half, dots: 3).spokenName == "half with 3 dots")
}

// SPEC.md §6.3 — tuplets are named where the ratio is recognisable and stated as
// a ratio otherwise. The fixtures hold 3:2, 6:4, 4:6, 2:1 and 2:3. Seven in the
// time of four is left to the ratio form, following the spec's own example.

@Test func namesTheRecognisableTupletRatios() {
    #expect(Duration(divisions: 4, type: .eighth,
                     tuplet: Tuplet(actual: 3, normal: 2)).spokenName == "triplet eighth")
    #expect(Duration(divisions: 2, type: .sixteenth,
                     tuplet: Tuplet(actual: 6, normal: 4)).spokenName == "sextuplet sixteenth")
    #expect(Duration(divisions: 8, type: .quarter,
                     tuplet: Tuplet(actual: 2, normal: 3)).spokenName == "duplet quarter")
}

@Test func statesUnrecognisableTupletsAsARatio() {
    #expect(Duration(divisions: 3, type: .eighth,
                     tuplet: Tuplet(actual: 4, normal: 6)).spokenName
            == "4 in the time of 6, eighth")
    #expect(Duration(divisions: 6, type: .sixteenth,
                     tuplet: Tuplet(actual: 7, normal: 4)).spokenName
            == "7 in the time of 4, sixteenth")
}

@Test func aOneToOneTimeModificationIsNotATuplet() {
    // music21 emits <time-modification> with no real modification; saying
    // "1 in the time of 1" would be noise.
    #expect(Duration(divisions: 12, type: .quarter,
                     tuplet: Tuplet(actual: 1, normal: 1)).spokenName == "quarter")
}

// SPEC.md §6.3 — a note with no <type> gets its name inferred from <duration> and
// the prevailing <divisions>. 23 notes in the OMR fixtures need this.

@Test func infersTheNotatedValueFromDivisionsWhenTypeIsAbsent() {
    // The Mayer declares <divisions>12</divisions>, so a quarter note lasts 12.
    #expect(Duration.inferring(divisions: 12, perQuarter: 12).spokenName == "quarter")
    #expect(Duration.inferring(divisions: 6, perQuarter: 12).spokenName == "eighth")
    #expect(Duration.inferring(divisions: 48, perQuarter: 12).spokenName == "whole")
    #expect(Duration.inferring(divisions: 24, perQuarter: 12).spokenName == "half")
    #expect(Duration.inferring(divisions: 3, perQuarter: 12).spokenName == "sixteenth")
}

@Test func infersDottedValuesToo() {
    #expect(Duration.inferring(divisions: 18, perQuarter: 12).spokenName == "dotted quarter")
    #expect(Duration.inferring(divisions: 9, perQuarter: 12).spokenName == "dotted eighth")
    #expect(Duration.inferring(divisions: 21, perQuarter: 12).spokenName
            == "double dotted quarter")
}

@Test func refusesToGuessWhenTheDurationIsNotARepresentableValue() {
    // SPEC §6.3: say the raw count rather than guess.
    #expect(Duration.inferring(divisions: 5, perQuarter: 12).spokenName
            == "duration 5 divisions")
    #expect(Duration.inferring(divisions: 0, perQuarter: 12).spokenName
            == "duration 0 divisions")
}

@Test func inferenceIsUnaffectedByAnUnusualDivisionsValue() {
    #expect(Duration.inferring(divisions: 8, perQuarter: 4).spokenName == "half")
    #expect(Duration.inferring(divisions: 1, perQuarter: 1).spokenName == "quarter")
    // A divisions value of zero cannot be divided by; it must not crash.
    #expect(Duration.inferring(divisions: 4, perQuarter: 0).spokenName
            == "duration 4 divisions")
}
