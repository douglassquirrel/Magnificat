/// A note as written, with everything needed to speak it.
public struct Note: Sendable, Equatable {
    /// The pitch as written.
    public var pitch: Pitch
    /// How long it lasts.
    public var duration: Duration
    /// The voice this note belongs to. Defaults to 1 when the file omits it,
    /// which most machine-generated MusicXML does. See `SPEC.md` §6.6.
    public var voice: Int = 1
    /// The staff this note is written on. Defaults to 1, as above.
    public var staff: Int = 1
    /// True for the second and later notes of a chord — MusicXML's `<chord/>`.
    /// A chord member sounds with the note before it rather than after.
    public var isChordMember: Bool = false
    /// True for a grace note — an ornamental note outside the measure's timing.
    /// Grace notes carry no `<duration>`, so they must not enter the arithmetic.
    public var isGrace: Bool = false
    /// The accidental the score prints, which is independent of `pitch.alter`:
    /// a note may sound flat with nothing printed. See `SPEC.md` §6.2.
    public var printedAccidental: Accidental?
    /// Where this note starts, in divisions from the start of the measure.
    /// Resolved from `<backup>` and `<forward>` while parsing.
    public var onset: Int = 0
}

/// A silence.
public struct Rest: Sendable, Equatable {
    /// How long it lasts.
    public var duration: Duration
    /// `<rest measure="yes"/>` — a bar's rest, whatever the time signature.
    public var isWholeMeasure: Bool
    /// The voice this rest belongs to. Defaults to 1.
    public var voice: Int = 1
    /// The staff this rest is written on. Defaults to 1.
    public var staff: Int = 1
    /// Where this rest starts, in divisions from the start of the measure.
    public var onset: Int = 0
}

/// One thing that happens in a measure, in reading order.
public enum MusicalEvent: Sendable, Equatable {
    case note(Note)
    case rest(Rest)
}

extension MusicalEvent {
    /// Where this event starts, in divisions from the start of the measure.
    public var onset: Int {
        switch self {
        case .note(let note): return note.onset
        case .rest(let rest): return rest.onset
        }
    }

    /// The voice this event belongs to.
    public var voice: Int {
        switch self {
        case .note(let note): return note.voice
        case .rest(let rest): return rest.voice
        }
    }

    /// The staff this event is written on.
    public var staff: Int {
        switch self {
        case .note(let note): return note.staff
        case .rest(let rest): return rest.staff
        }
    }
}

/// A time signature. A score may have none at all — the Parry in the fixtures
/// does not — and its absence is information, not a default of 4/4.
public struct TimeSignature: Sendable, Equatable {
    /// The upper number.
    public var beats: Int
    /// The lower number.
    public var beatType: Int

    public init(beats: Int, beatType: Int) {
        self.beats = beats
        self.beatType = beatType
    }
}

/// What a measure restates about the music: divisions, key, meter, staff count.
/// Present only on measures where the file says something; scores restate these
/// mid-piece routinely.
public struct MeasureAttributes: Sendable, Equatable {
    /// Divisions per quarter note, for duration arithmetic.
    public var divisions: Int?
    /// The key signature from this measure onwards.
    public var key: KeySignature?
    /// The meter from this measure onwards.
    public var time: TimeSignature?
    /// How many staves this part uses. Two means a grand staff.
    public var staves: Int?

    /// True when the file said nothing worth recording.
    var isEmpty: Bool {
        divisions == nil && key == nil && time == nil && staves == nil
    }
}

/// One measure of one part.
public struct Measure: Sendable, Equatable {
    /// The number as printed. MusicXML numbers are strings: `0`, `1`, `12a`.
    public var number: String
    /// True for a pickup measure — MusicXML's `implicit="yes"`.
    public var isPickup: Bool = false
    /// What this measure restates, if anything.
    public var attributes: MeasureAttributes?
    /// The events of the measure, in reading order.
    public var events: [MusicalEvent] = []
}

/// One part of a score — a singer's line, or a pianist's grand staff.
public struct Part: Sendable, Equatable {
    /// MusicXML's part ID. Often a 32-character hash in machine-generated files.
    public var id: String
    /// The part name, when the file gives one. Frequently blank in OMR output.
    public var name: String?
    /// The measures, in document order.
    public var measures: [Measure]
}

/// A parsed MusicXML score.
///
/// This is the faithful layer: it holds what the file said, with no English in it.
/// Rendering to plain text is a separate step. See `SPEC.md` §4.
public struct Score: Sendable, Equatable {
    /// The parts, in document order.
    public var parts: [Part]
}
