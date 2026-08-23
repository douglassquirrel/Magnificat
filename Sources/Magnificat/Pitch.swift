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
