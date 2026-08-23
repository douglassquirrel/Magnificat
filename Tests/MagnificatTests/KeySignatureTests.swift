import Testing
@testable import Magnificat

// SPEC.md §6.2 — a key signature decides which steps are altered, which is what
// makes a printed natural meaningful.

@Test func aKeyOfNoSharpsOrFlatsAltersNothing() {
    let key = KeySignature(fifths: 0)
    #expect(Step.allCases.allSatisfy { key.alteration(of: $0) == 0 })
}

@Test func flatKeysAlterStepsInTheOrderBEADGCF() {
    // A flat major, four flats: B flat, E flat, A flat, D flat.
    let aFlat = KeySignature(fifths: -4)
    #expect(aFlat.alteration(of: .b) == -1)
    #expect(aFlat.alteration(of: .e) == -1)
    #expect(aFlat.alteration(of: .a) == -1)
    #expect(aFlat.alteration(of: .d) == -1)
    #expect(aFlat.alteration(of: .g) == 0)
    #expect(aFlat.alteration(of: .c) == 0)
    #expect(aFlat.alteration(of: .f) == 0)
}

@Test func sharpKeysAlterStepsInTheOrderFCGDAEB() {
    // D major, two sharps: F sharp, C sharp.
    let d = KeySignature(fifths: 2)
    #expect(d.alteration(of: .f) == 1)
    #expect(d.alteration(of: .c) == 1)
    #expect(d.alteration(of: .g) == 0)
    #expect(d.alteration(of: .b) == 0)
}

@Test func theExtremeKeysAlterEveryStep() {
    #expect(Step.allCases.allSatisfy { KeySignature(fifths: 7).alteration(of: $0) == 1 })
    #expect(Step.allCases.allSatisfy { KeySignature(fifths: -7).alteration(of: $0) == -1 })
}
