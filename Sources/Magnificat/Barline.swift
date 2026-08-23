/// A barline, and whatever it carries: a repeat, an ending bracket, a style.
///
/// A sighted player sees these as shapes at the edge of a system. A reader has
/// to be told. See `SPEC.md` §6.12.
public struct Barline: Sendable, Equatable {
    /// Which side of the measure this barline sits on.
    public enum Location: Sendable, Equatable { case left, right }
    /// Which way a repeat sends the player.
    public enum RepeatDirection: Sendable, Equatable { case forward, backward }
    /// Whether an ending bracket opens or closes here.
    public enum EndingType: Sendable, Equatable { case start, stop, discontinue }

    public var location: Location = .right
    /// MusicXML's `<bar-style>`, verbatim.
    public var style: String?
    public var repeatDirection: RepeatDirection?
    /// The ending number as printed — `1`, `2`, sometimes `1,2`.
    public var endingNumber: String?
    public var endingType: EndingType?

    /// The barline spoken as plain text, in reading order. A single barline can
    /// carry more than one thing: an ending bracket and a repeat together.
    ///
    /// `repeatTarget` is the measure a backward repeat jumps to, which the
    /// barline itself does not record.
    func spokenPhrases(repeatTarget: String) -> [String] {
        var phrases: [String] = []

        if let endingType, let number = endingNumber {
            switch endingType {
            case .start: phrases.append("\(Self.ordinal(number)) ending begins")
            case .stop, .discontinue: phrases.append("Ending finishes")
            }
        }

        switch repeatDirection {
        case .forward:
            phrases.append("Repeat: forward repeat begins here")
        case .backward:
            phrases.append("Repeat: go back to the start of measure \(repeatTarget)")
        case nil:
            break
        }

        switch style {
        case "light-light": phrases.append("Double barline")
        case "light-heavy": phrases.append("Final barline")
        default: break
        }
        return phrases
    }

    /// "1" becomes "First". Anything unexpected — MusicXML allows `1,2` — is
    /// spoken as written rather than mangled into an ordinal that lies.
    static func ordinal(_ number: String) -> String {
        switch number {
        case "1": return "First"
        case "2": return "Second"
        case "3": return "Third"
        case "4": return "Fourth"
        default: return "Ending \(number)"
        }
    }
}
