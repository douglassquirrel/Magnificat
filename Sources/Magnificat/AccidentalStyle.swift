/// Whether the transcript states the pitch that sounds, or only the accidentals
/// the score prints. See `SPEC.md` §6.2.
public enum AccidentalStyle: Sendable, Equatable {
    /// Say the pitch to play, whether or not the score prints an accidental.
    case sounding
    /// Say only what is printed, leaving the reader to apply the key signature.
    case asPrinted
}

/// An accidental as printed on the page — MusicXML's `<accidental>` element.
///
/// This is the *visual* symbol. The sounding alteration lives in `Pitch.alter`,
/// and the two are independent: a note may sound flat with nothing printed.
public enum Accidental: Sendable, Equatable {
    case flat, sharp, natural, doubleFlat, doubleSharp

    /// The accidental as an English word.
    var spokenWord: String {
        switch self {
        case .flat: return "flat"
        case .sharp: return "sharp"
        case .natural: return "natural"
        case .doubleFlat: return "double flat"
        case .doubleSharp: return "double sharp"
        }
    }
}
