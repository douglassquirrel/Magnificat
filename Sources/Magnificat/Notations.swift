/// A mark attached to a note that says how to play it. See `SPEC.md` §6.10.
public enum Articulation: Sendable, Equatable {
    case staccato, staccatissimo, accent, marcato, tenuto, breathMark

    init?(musicXML: String) {
        switch musicXML {
        case "staccato": self = .staccato
        case "staccatissimo": self = .staccatissimo
        case "accent": self = .accent
        case "strong-accent": self = .marcato
        case "tenuto": self = .tenuto
        case "breath-mark": self = .breathMark
        default: return nil
        }
    }

    var spokenWord: String {
        switch self {
        case .staccato: return "staccato"
        case .staccatissimo: return "staccatissimo"
        case .accent: return "accent"
        case .marcato: return "marcato"
        case .tenuto: return "tenuto"
        case .breathMark: return "breath mark"
        }
    }
}

/// A decoration named but never realised into notes. See `SPEC.md` §6.10.
public enum Ornament: Sendable, Equatable {
    case trill, mordent, invertedMordent, turn, invertedTurn

    init?(musicXML: String) {
        switch musicXML {
        case "trill-mark": self = .trill
        case "mordent": self = .mordent
        case "inverted-mordent": self = .invertedMordent
        case "turn": self = .turn
        case "inverted-turn": self = .invertedTurn
        default: return nil
        }
    }

    var spokenWord: String {
        switch self {
        case .trill: return "trill"
        case .mordent: return "mordent"
        case .invertedMordent: return "inverted mordent"
        case .turn: return "turn"
        case .invertedTurn: return "inverted turn"
        }
    }
}

/// Whether a note starts a tie, continues one, or both.
public struct TieState: Sendable, Equatable {
    public var starts: Bool = false
    public var stops: Bool = false
}

/// Whether a slur begins or ends on a note. Both can happen at once.
public struct SlurState: Sendable, Equatable {
    public var begins: Bool = false
    public var ends: Bool = false
}
