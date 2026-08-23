/// Where a syllable sits in its word — MusicXML's `<syllabic>`.
///
/// This is what tells a reader whether the word continues, which is the whole
/// job of the hyphens in the transcript. See `SPEC.md` §6.11.
public enum Syllabic: Sendable, Equatable {
    case single, begin, middle, end

    init(musicXML: String) {
        switch musicXML {
        case "begin": self = .begin
        case "middle": self = .middle
        case "end": self = .end
        default: self = .single
        }
    }

    /// True when a syllable precedes it in the same word.
    var continuesFromPrevious: Bool { self == .middle || self == .end }
    /// True when a syllable follows it in the same word.
    var continuesToNext: Bool { self == .begin || self == .middle }
}

/// One syllable of one verse, sung on one note.
public struct Lyric: Sendable, Equatable {
    /// The verse number, from `<lyric number="...">`. The fixtures reach three.
    public var verse: Int
    /// The syllable exactly as the file gives it, including any non-ASCII.
    public var text: String
    /// Where the syllable sits in its word.
    public var syllabic: Syllabic

    public init(verse: Int, text: String, syllabic: Syllabic) {
        self.verse = verse
        self.text = text
        self.syllabic = syllabic
    }

    /// The syllable with the hyphens that show whether the word continues.
    var hyphenated: String {
        let leading = syllabic.continuesFromPrevious ? "-" : ""
        let trailing = syllabic.continuesToNext ? "-" : ""
        return leading + text + trailing
    }
}
