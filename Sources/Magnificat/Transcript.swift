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
    /// Musical incoherence found while rendering. Never fatal; empty for a clean
    /// file. See `SPEC.md` §6.15.
    public var anomalies: [Anomaly]

    public init(lines: [TranscriptLine], anomalies: [Anomaly] = []) {
        self.lines = lines
        self.anomalies = anomalies
    }

    /// The transcript as plain text: lines joined with `\n`, one trailing newline,
    /// no `\r` anywhere. See `SPEC.md` §6.1.
    public var plainText: String {
        lines.map(\.text).joined(separator: "\n") + "\n"
    }

    /// A summary of `anomalies`, one line per anomaly naming its measure, or
    /// `nil` when there are none. Plain English throughout — `Anomaly.detail`
    /// is already documented as safe to show a user — so this obeys `SPEC.md`
    /// §6.1's ASCII rule with no extra work.
    public var anomalySummary: String? {
        guard !anomalies.isEmpty else { return nil }
        let count = anomalies.count
        var lines = ["\(count) \(count == 1 ? "anomaly" : "anomalies") found in this file:"]
        lines += anomalies.map { "Measure \($0.measureNumber): \($0.detail)" }
        return lines.joined(separator: "\n")
    }

    /// A fixed reminder that this text came from machine recognition of a scanned
    /// page, not a verified transcription. Shown unconditionally: recognition can
    /// misread music without tripping any of the checks in `Coherence.swift`, so
    /// the absence of a listed anomaly is not proof the page was read correctly.
    private static let omrDisclaimer = "This text was produced by machine recognition "
        + "of a scanned page and may contain errors"

    /// `omrDisclaimer`, followed by `anomalySummary` when there is one, then
    /// `plainText`. Unlike `anomalySummary`, this is never `nil` and never
    /// simply equals `plainText` — the disclaimer is unconditional.
    public var plainTextWithAnomalySummary: String {
        var header = Self.omrDisclaimer
        if let anomalySummary {
            header += "\n" + anomalySummary
        }
        return header + "\n\n" + plainText
    }
}
