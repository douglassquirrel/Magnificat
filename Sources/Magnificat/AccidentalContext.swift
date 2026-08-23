/// Tracks what is in force when a pitch is spoken: the key signature, and any
/// accidentals already seen in the current measure.
///
/// This exists so that a bare letter in the transcript means "unaltered, and
/// nothing in force would have altered it". Where something would have, the word
/// `natural` is spoken instead. See `SPEC.md` §6.2.
struct AccidentalContext {
    /// The key signature currently in force.
    var key: KeySignature

    /// Whether to speak the sounding pitch or only what the score prints.
    var style: AccidentalStyle

    /// Accidentals seen so far in this measure, keyed by step *and* octave.
    /// MusicXML's `<alter>` is the sounding alteration, so recording it directly
    /// is enough; no separate notion of a printed accidental is needed here.
    private var measureAccidentals: [Slot: Int] = [:]

    /// A step in a particular octave — the scope an accidental applies to.
    private struct Slot: Hashable {
        var step: Step
        var octave: Int
    }

    init(key: KeySignature, style: AccidentalStyle = .sounding) {
        self.key = key
        self.style = style
    }

    /// Cancels measure-local accidentals at a barline. The key signature survives.
    ///
    /// See `SPEC.md` §6.2. Ties across a barline are handled by the caller, which
    /// knows about ties; this type only knows about measures.
    mutating func startNewMeasure() {
        measureAccidentals.removeAll(keepingCapacity: true)
    }

    /// The pitch spoken as plain text, in this context.
    mutating func spokenName(of pitch: Pitch,
                             printedAccidental: Accidental? = nil) -> String {
        let slot = Slot(step: pitch.step, octave: pitch.octave)
        let wouldHaveBeenAltered = key.alteration(of: pitch.step) != 0
            || (measureAccidentals[slot] ?? 0) != 0
        measureAccidentals[slot] = pitch.alter

        if style == .asPrinted {
            guard let printed = printedAccidental else {
                return "\(pitch.step.rawValue) \(pitch.octave)"
            }
            return "\(pitch.step.rawValue) \(printed.spokenWord) \(pitch.octave)"
        }

        if let word = Self.accidentalWord(for: pitch.alter) {
            return "\(pitch.step.rawValue) \(word) \(pitch.octave)"
        }
        if wouldHaveBeenAltered {
            return "\(pitch.step.rawValue) natural \(pitch.octave)"
        }
        return "\(pitch.step.rawValue) \(pitch.octave)"
    }

    /// The alteration as an English word, or `nil` when the pitch is unaltered.
    static func accidentalWord(for alter: Int) -> String? {
        switch alter {
        case -2: return "double flat"
        case -1: return "flat"
        case 1: return "sharp"
        case 2: return "double sharp"
        default: return nil
        }
    }
}
