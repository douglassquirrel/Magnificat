/// Something written near the staff rather than on it: a dynamic, a tempo
/// marking, a hairpin, a pedal mark. See `SPEC.md` §6.9.
public enum Direction: Sendable, Equatable {
    /// A dynamic marking, as its MusicXML element name (`p`, `ff`, `sf`).
    case dynamic(String)
    /// Free text, passed through exactly as written.
    case words(String)

    /// The direction spoken as plain text.
    var spokenText: String {
        switch self {
        case .dynamic(let mark):
            // Always prefixed. A bare "Piano" at the start of a line is ambiguous
            // between the instrument and the dynamic.
            return "Dynamic: \(Self.dynamicWord(mark))"
        case .words(let text):
            return text
        }
    }

    /// A dynamic marking as an English word.
    ///
    /// Counts are spoken as counts — `triple forte` rather than `fortississimo` —
    /// because the Italian superlatives are hard to tell apart in speech, which
    /// is the whole difficulty this library is trying to remove.
    static func dynamicWord(_ mark: String) -> String {
        switch mark {
        case "pppp": return "quadruple piano"
        case "ppp": return "triple piano"
        case "pp": return "pianissimo"
        case "p": return "piano"
        case "mp": return "mezzo piano"
        case "mf": return "mezzo forte"
        case "f": return "forte"
        case "ff": return "fortissimo"
        case "fff": return "triple forte"
        case "ffff": return "quadruple forte"
        case "sf", "sfz": return "sforzando"
        case "sfp": return "sforzando piano"
        case "fp": return "forte piano"
        case "rf", "rfz": return "rinforzando"
        // Anything the standard does not name is spoken as written rather than
        // dropped: SPEC §6.13 reflects what the file says.
        default: return mark
        }
    }
}
