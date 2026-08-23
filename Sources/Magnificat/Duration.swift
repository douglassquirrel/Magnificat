/// A notated note value — MusicXML's `<type>` element.
///
/// The names spoken are American throughout (`quarter`, `eighth`), which
/// `SPEC.md` §13 fixes deliberately: there is no British option.
public enum NoteType: Sendable, Equatable, CaseIterable {
    case breve, whole, half, quarter, eighth, sixteenth, thirtySecond, sixtyFourth

    /// The value spoken as plain text.
    var spokenName: String {
        switch self {
        case .breve: return "breve"
        case .whole: return "whole"
        case .half: return "half"
        case .quarter: return "quarter"
        case .eighth: return "eighth"
        case .sixteenth: return "sixteenth"
        case .thirtySecond: return "thirty-second"
        case .sixtyFourth: return "sixty-fourth"
        }
    }

    /// Reads MusicXML's spelling, which uses `16th`, `32nd` and `64th` rather
    /// than words. Returns `nil` for a value this library does not name.
    init?(musicXML: String) {
        switch musicXML {
        case "breve": self = .breve
        case "whole": self = .whole
        case "half": self = .half
        case "quarter": self = .quarter
        case "eighth": self = .eighth
        case "16th": self = .sixteenth
        case "32nd": self = .thirtySecond
        case "64th": self = .sixtyFourth
        default: return nil
        }
    }
}

/// A tuplet ratio — MusicXML's `<time-modification>`: this many notes played in
/// the time of that many.
public struct Tuplet: Sendable, Equatable {
    /// `<actual-notes>` — how many are played.
    public var actual: Int
    /// `<normal-notes>` — the time they occupy.
    public var normal: Int

    public init(actual: Int, normal: Int) {
        self.actual = actual
        self.normal = normal
    }

    /// The conventional name for this ratio, or `nil` when there is none and the
    /// ratio should be spoken instead. See `SPEC.md` §6.3.
    var conventionalName: String? {
        switch (actual, normal) {
        case (2, 3): return "duplet"
        case (3, 2): return "triplet"
        case (5, 4): return "quintuplet"
        case (6, 4): return "sextuplet"
        default: return nil
        }
    }

    /// True when the ratio modifies nothing, as music21 sometimes emits.
    var isTrivial: Bool { actual == normal }
}

/// How long a note or rest lasts, in both of MusicXML's currencies: the notated
/// value that gets spoken, and the divisions count used for arithmetic.
public struct Duration: Sendable, Equatable {
    /// MusicXML's `<duration>`, in divisions of a quarter note. Never spoken.
    public var divisions: Int
    /// MusicXML's `<type>`. Absent on some real notes; see `SPEC.md` §6.3.
    public var type: NoteType?
    /// Augmentation dots. Real music reaches two; three is legal and named.
    public var dots: Int
    /// The tuplet ratio this note belongs to, if any.
    public var tuplet: Tuplet?

    public init(divisions: Int, type: NoteType? = nil, dots: Int = 0,
                tuplet: Tuplet? = nil) {
        self.divisions = divisions
        self.type = type
        self.dots = dots
        self.tuplet = tuplet
    }
}

extension NoteType {
    /// This value's length in quarter notes, as an exact fraction.
    /// Kept rational so that inference never depends on floating point.
    var quartersNumerator: Int {
        switch self {
        case .breve: return 8
        case .whole: return 4
        case .half: return 2
        case .quarter, .eighth, .sixteenth, .thirtySecond, .sixtyFourth: return 1
        }
    }

    var quartersDenominator: Int {
        switch self {
        case .breve, .whole, .half, .quarter: return 1
        case .eighth: return 2
        case .sixteenth: return 4
        case .thirtySecond: return 8
        case .sixtyFourth: return 16
        }
    }
}

extension Duration {
    /// Builds a duration for a note that carries no `<type>`, inferring the notated
    /// value from the divisions count.
    ///
    /// Where the count does not land exactly on a representable value, `type` is
    /// left `nil` and the raw count is spoken instead — `SPEC.md` §6.3 requires
    /// saying the count rather than guessing.
    static func inferring(divisions: Int, perQuarter: Int) -> Duration {
        guard divisions > 0, perQuarter > 0 else {
            return Duration(divisions: divisions)
        }
        // Longest first, so a value is named by the largest note that fits it
        // exactly rather than by an equivalent with more dots.
        for type in [NoteType.breve, .whole, .half, .quarter, .eighth,
                     .sixteenth, .thirtySecond, .sixtyFourth] {
            for dots in 0...2 {
                // length = perQuarter * num * (2^(dots+1) - 1) / (den * 2^dots)
                let dotNumerator = (1 << (dots + 1)) - 1
                let dotDenominator = 1 << dots
                let numerator = perQuarter * type.quartersNumerator * dotNumerator
                let denominator = type.quartersDenominator * dotDenominator
                guard numerator % denominator == 0 else { continue }
                if numerator / denominator == divisions {
                    return Duration(divisions: divisions, type: type, dots: dots)
                }
            }
        }
        return Duration(divisions: divisions)
    }

    /// The duration spoken as plain text, as `SPEC.md` §6.3 defines it.
    var spokenName: String {
        guard let type else { return "duration \(divisions) divisions" }
        let dotted: String
        switch dots {
        case 0: dotted = type.spokenName
        case 1: dotted = "dotted \(type.spokenName)"
        case 2: dotted = "double dotted \(type.spokenName)"
        default: dotted = "\(type.spokenName) with \(dots) dots"
        }

        guard let tuplet, !tuplet.isTrivial else { return dotted }
        if let name = tuplet.conventionalName { return "\(name) \(dotted)" }
        return "\(tuplet.actual) in the time of \(tuplet.normal), \(dotted)"
    }
}
