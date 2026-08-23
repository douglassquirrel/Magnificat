/// A letter name of the diatonic scale, as written on the staff.
public enum Step: String, Sendable, Equatable, CaseIterable {
    case c = "C", d = "D", e = "E", f = "F", g = "G", a = "A", b = "B"
}

/// A pitch as written: a letter, a chromatic alteration, and an octave.
///
/// Octave numbering is scientific — octave 4 begins at middle C — which coincides
/// with braille music's octave numbering. See `SPEC.md` §6.2.
public struct Pitch: Sendable, Equatable {
    /// The letter name.
    public var step: Step
    /// Chromatic alteration in semitones: -2 (double flat) to +2 (double sharp).
    public var alter: Int
    /// Scientific octave number; 4 is the octave beginning at middle C.
    public var octave: Int

    public init(step: Step, alter: Int, octave: Int) {
        self.step = step
        self.alter = alter
        self.octave = octave
    }
}

extension Pitch {
    /// Semitones above C-1, so two pitches can be ordered by what they sound
    /// rather than by their letters. B sharp 4 sits above B 4 and alongside C 5,
    /// which letter ordering alone would get wrong.
    var chromaticValue: Int {
        let semitonesAboveC: Int
        switch step {
        case .c: semitonesAboveC = 0
        case .d: semitonesAboveC = 2
        case .e: semitonesAboveC = 4
        case .f: semitonesAboveC = 5
        case .g: semitonesAboveC = 7
        case .a: semitonesAboveC = 9
        case .b: semitonesAboveC = 11
        }
        return (octave + 1) * 12 + semitonesAboveC + alter
    }

    /// The pitch spoken as plain text, as `SPEC.md` §6.2 defines it.
    var spokenName: String {
        if let word = accidentalWord {
            return "\(step.rawValue) \(word) \(octave)"
        }
        return "\(step.rawValue) \(octave)"
    }

    /// The alteration as an English word, or `nil` when the pitch is unaltered.
    private var accidentalWord: String? {
        switch alter {
        case -2: return "double flat"
        case -1: return "flat"
        case 1: return "sharp"
        case 2: return "double sharp"
        default: return nil
        }
    }
}
