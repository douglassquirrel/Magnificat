/// How a transcript is ordered. See `SPEC.md` §6.7.
public enum TranscriptLayout: Sendable, Equatable {
    /// The whole of one part, then the whole of the next. The commonest task is
    /// learning one line, so this is the default.
    case byPart
    /// Measure 1 of every stream, then measure 2 — for fitting parts together.
    case byMeasure
}

/// How much goes on a line. See `SPEC.md` §6.8.
public enum TranscriptDensity: Sendable, Equatable {
    /// One line per measure. Best for continuous reading in speech.
    case perMeasure
    /// A measure line, then one line per event. Best for a braille display and
    /// for arrow-key navigation note by note.
    case perEvent
}

/// The knobs on a transcript, all defaulted. See `SPEC.md` §5.
public struct TranscriptOptions: Sendable, Equatable {
    /// The whole of one part at a time, or measure by measure across parts.
    public var layout: TranscriptLayout
    /// One line per measure, or one line per event.
    public var density: TranscriptDensity
    /// Say the pitch that sounds, or only what the score prints.
    public var accidentalStyle: AccidentalStyle

    public init(layout: TranscriptLayout = .byPart,
                density: TranscriptDensity = .perMeasure,
                accidentalStyle: AccidentalStyle = .sounding) {
        self.layout = layout
        self.density = density
        self.accidentalStyle = accidentalStyle
    }
}

/// One line of a transcript. Every line stands alone and is meaningful when read
/// out of context, which is what makes the transcript navigable. See `SPEC.md` §6.1.
public struct TranscriptLine: Sendable, Equatable {
    /// What this line says about the music.
    public enum Kind: Sendable, Equatable {
        case scoreHeading, partHeading, measure, event, direction, lyricsSummary, blank
    }

    /// The text of the line: no leading or trailing spaces, no tabs.
    public var text: String
    /// What the line is, so a host app can style or navigate by it.
    public var kind: Kind
    /// The part this line belongs to, or `nil` for score-level lines.
    public var partID: String?
    /// The measure this line belongs to, or `nil` outside a measure.
    public var measureNumber: String?

    public init(text: String, kind: Kind, partID: String? = nil,
                measureNumber: String? = nil) {
        self.text = text
        self.kind = kind
        self.partID = partID
        self.measureNumber = measureNumber
    }
}

/// A rendered transcript: structured lines, and the plain text they join into.
public struct Transcript: Sendable, Equatable {
    /// The lines, in reading order.
    public var lines: [TranscriptLine]

    public init(lines: [TranscriptLine]) {
        self.lines = lines
    }

    /// The transcript as plain text: lines joined with `\n`, one trailing newline,
    /// no `\r` anywhere. See `SPEC.md` §6.1.
    public var plainText: String {
        lines.map(\.text).joined(separator: "\n") + "\n"
    }
}
