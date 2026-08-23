/// Something written near the staff rather than on it: a dynamic, a tempo
/// marking, a hairpin, a pedal mark. See `SPEC.md` §6.9.
public enum Direction: Sendable, Equatable {
    /// A dynamic marking, as its MusicXML element name (`p`, `ff`, `sf`).
    case dynamic(String)
    /// Free text, passed through exactly as written.
    case words(String)
    /// A hairpin beginning. The kind is carried so its stop can name it.
    case wedgeStart(isCrescendo: Bool)
    /// A hairpin ending, naming the hairpin it closes.
    case wedgeStop(wasCrescendo: Bool)
    /// The sustaining pedal going down or coming up.
    case pedal(isDown: Bool)
    /// An octave transposition beginning, or ending.
    case octaveShiftStart(isDown: Bool)
    case octaveShiftStop
    /// A rehearsal mark.
    case rehearsal(String)
    /// A metronome mark: a beat unit, its dots, and a rate.
    case metronome(beatUnit: String, dots: Int, perMinute: String)

    /// The direction spoken as plain text.
    var spokenText: String {
        switch self {
        case .dynamic(let mark):
            // Always prefixed. A bare "Piano" at the start of a line is ambiguous
            // between the instrument and the dynamic.
            return "Dynamic: \(Self.dynamicWord(mark))"
        case .words(let text):
            return text
        case .wedgeStart(let isCrescendo):
            return isCrescendo ? "Crescendo begins" : "Diminuendo begins"
        case .wedgeStop(let wasCrescendo):
            // <wedge type="stop"/> does not say which hairpin it closes, so the
            // reader is told, rather than left with a bare "Hairpin ends".
            return wasCrescendo ? "Crescendo ends" : "Diminuendo ends"
        case .pedal(let isDown):
            return isDown ? "Pedal down" : "Pedal up"
        case .octaveShiftStart(let isDown):
            return "Octave shift \(isDown ? "down" : "up") begins"
        case .octaveShiftStop:
            return "Octave shift ends"
        case .rehearsal(let mark):
            return "Rehearsal mark \(mark)"
        case .metronome(let unit, let dots, let perMinute):
            let dotted = dots == 1 ? "dotted " : dots == 2 ? "double dotted " : ""
            return "Tempo: \(dotted)\(unit) note equals \(perMinute)"
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
