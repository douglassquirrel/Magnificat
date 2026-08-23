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

    /// Reads MusicXML's `<accidental>` spelling. Returns `nil` for values this
    /// library does not name, which are skipped rather than refused.
    init?(musicXML: String) {
        switch musicXML {
        case "flat": self = .flat
        case "sharp": self = .sharp
        case "natural": self = .natural
        case "flat-flat", "double-flat": self = .doubleFlat
        case "double-sharp", "sharp-sharp": self = .doubleSharp
        default: return nil
        }
    }

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
