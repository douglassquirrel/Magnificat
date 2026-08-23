import Foundation

extension Score {
    /// Parses a MusicXML document.
    ///
    /// The document must be uncompressed `score-partwise`, with or without a
    /// DOCTYPE — most machine-generated MusicXML carries none, and the root
    /// element decides, not the DOCTYPE. See `SPEC.md` §6.14.
    ///
    /// - Throws: ``TranscriptionError``.
    public init(musicXML data: Data) throws {
        // A .mxl is a zip archive. SPEC.md §13 makes unzipping a non-goal, so it
        // is detected by its signature and refused clearly, rather than reaching
        // the XML parser and being reported as malformed.
        if data.starts(with: [0x50, 0x4B, 0x03, 0x04]) {
            throw TranscriptionError.unsupportedFormat("compressed .mxl")
        }

        let handler = MusicXMLHandler()
        let parser = XMLParser(data: data)
        parser.delegate = handler
        // Never resolve external entities: a MusicXML DOCTYPE points at
        // musicxml.org, and resolving it would put a silent network request in a
        // library that promises never to make one. SPEC.md §6.14.
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            if let failure = handler.failure { throw failure }
            let error = parser.parserError as NSError?
            throw TranscriptionError.malformedXML(
                line: parser.lineNumber,
                message: error?.localizedDescription ?? "could not be parsed")
        }
        if let failure = handler.failure { throw failure }

        let score = handler.makeScore()
        guard !score.parts.isEmpty,
              score.parts.contains(where: { !$0.measures.isEmpty }) else {
            throw TranscriptionError.emptyScore
        }
        self = score
    }
}

/// Reads MusicXML with `XMLParser`, Foundation's streaming parser.
///
/// `XMLDocument` — the validating, tree-building API — does not exist on iOS, so
/// this is not a stylistic choice. See `SPEC.md` §9.
final class MusicXMLHandler: NSObject, XMLParserDelegate {
    /// Set when the document is structurally unusable; surfaces after parsing stops.
    private(set) var failure: TranscriptionError?

    private var sawRoot = false
    private var text = ""
    private var elements: [String] = []

    // Part list: id in document order, and the names found for them.
    private var metadata = ScoreMetadata()
    private var creatorType: String?
    private var partOrder: [String] = []
    private var partNames: [String: String] = [:]
    private var currentScorePartID: String?

    // The part being read.
    private var currentPartID: String?
    private var measures: [Measure] = []
    private var parts: [Part] = []

    // The measure being read.
    private var measureNumber = ""
    private var measureIsPickup = false
    private var attributes = MeasureAttributes()
    private var events: [MusicalEvent] = []
    /// Position within the measure, in divisions. `<backup>` moves it back so a
    /// second voice can start where the first did; `<forward>` skips a gap.
    private var cursor = 0
    /// Where the previous non-chord event started, so chord members can share it.
    private var lastOnset = 0
    private var shiftDuration: Int?
    private var keyFifths: Int?
    private var keyMode: String?
    private var timeBeats: Int?
    private var timeBeatType: Int?

    // The note being read.
    private var noteStep: Step?
    private var noteAlter = 0
    private var noteOctave: Int?
    private var noteDuration: Int?
    private var noteType: NoteType?
    private var noteIsRest = false
    private var noteIsWholeMeasureRest = false
    private var noteVoice = 1
    private var noteStaff = 1
    private var noteDots = 0
    private var noteIsChordMember = false
    private var noteIsGrace = false
    private var notePrintedAccidental: Accidental?
    private var measureBarlines: [Barline] = []
    private var currentBarline: Barline?
    private var directionStaff: Int?
    /// Whether the hairpin currently open is a crescendo, so its stop can name it.
    private var openWedgeIsCrescendo = true
    private var metronomeUnit: String?
    private var metronomeDots = 0
    private var metronomePerMinute: String?
    private var pendingDirections: [Direction] = []
    private var noteTie = TieState()
    private var noteSlur = SlurState()
    private var noteArticulations: [Articulation] = []
    private var noteOrnaments: [Ornament] = []
    private var noteIsArpeggiated = false
    private var noteHasFermata = false
    private var noteIsCue = false
    private var noteLyrics: [Lyric] = []
    private var lyricVerse = 1
    private var lyricText: String?
    private var lyricSyllabic: Syllabic = .single
    private var tupletActual: Int?
    private var tupletNormal: Int?

    func makeScore() -> Score {
        Score(metadata: metadata, parts: parts)
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement name: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String]) {
        if !sawRoot {
            sawRoot = true
            guard name == "score-partwise" else {
                failure = .unsupportedRootElement(found: name)
                parser.abortParsing()
                return
            }
        }
        elements.append(name)
        text = ""

        switch name {
        case "score-part":
            currentScorePartID = attributes["id"]
        case "creator":
            creatorType = attributes["type"]
        case "part":
            currentPartID = attributes["id"]
            measures = []
        case "measure":
            measureNumber = attributes["number"] ?? ""
            measureIsPickup = attributes["implicit"] == "yes"
            self.attributes = MeasureAttributes()
            events = []
            cursor = 0
            lastOnset = 0
            measureBarlines = []
        case "barline":
            var barline = Barline()
            barline.location = attributes["location"] == "left" ? .left : .right
            currentBarline = barline
        case "repeat":
            switch attributes["direction"] {
            case "forward": currentBarline?.repeatDirection = .forward
            case "backward": currentBarline?.repeatDirection = .backward
            default: break
            }
        case "ending":
            currentBarline?.endingNumber = attributes["number"]
            switch attributes["type"] {
            case "start": currentBarline?.endingType = .start
            case "stop": currentBarline?.endingType = .stop
            case "discontinue": currentBarline?.endingType = .discontinue
            default: break
            }
        case "backup", "forward":
            shiftDuration = nil
        case "attributes":
            keyFifths = nil
            keyMode = nil
            timeBeats = nil
            timeBeatType = nil
        case "note":
            resetNote()
        case "chord":
            noteIsChordMember = true
        case "grace":
            noteIsGrace = true
        case "cue":
            noteIsCue = true
        case "tie", "tied":
            switch attributes["type"] {
            case "start": noteTie.starts = true
            case "stop": noteTie.stops = true
            default: break
            }
        case "slur":
            switch attributes["type"] {
            case "start": noteSlur.begins = true
            case "stop": noteSlur.ends = true
            default: break
            }
        case "arpeggiate":
            noteIsArpeggiated = true
        case "fermata":
            noteHasFermata = true
        case "staccato", "staccatissimo", "accent", "strong-accent", "tenuto",
             "breath-mark":
            if let articulation = Articulation(musicXML: name) {
                noteArticulations.append(articulation)
            }
        case "trill-mark", "mordent", "inverted-mordent", "turn", "inverted-turn":
            if let ornament = Ornament(musicXML: name) {
                noteOrnaments.append(ornament)
            }
        case "direction":
            pendingDirections = []
            directionStaff = nil
        case "p", "pp", "ppp", "pppp", "f", "ff", "fff", "ffff",
             "mp", "mf", "sf", "sfz", "sfp", "fp", "rf", "rfz":
            if elements.dropLast().last == "dynamics" {
                pendingDirections.append(.dynamic(name))
            }
        case "wedge":
            switch attributes["type"] {
            case "crescendo":
                openWedgeIsCrescendo = true
                pendingDirections.append(.wedgeStart(isCrescendo: true))
            case "diminuendo":
                openWedgeIsCrescendo = false
                pendingDirections.append(.wedgeStart(isCrescendo: false))
            case "stop":
                pendingDirections.append(.wedgeStop(wasCrescendo: openWedgeIsCrescendo))
            default:
                break
            }
        case "pedal":
            switch attributes["type"] {
            case "start": pendingDirections.append(.pedal(isDown: true))
            case "stop": pendingDirections.append(.pedal(isDown: false))
            default: break
            }
        case "octave-shift":
            switch attributes["type"] {
            case "down": pendingDirections.append(.octaveShiftStart(isDown: true))
            case "up": pendingDirections.append(.octaveShiftStart(isDown: false))
            case "stop": pendingDirections.append(.octaveShiftStop)
            default: break
            }
        case "metronome":
            metronomeUnit = nil
            metronomeDots = 0
            metronomePerMinute = nil
        case "beat-unit-dot":
            metronomeDots += 1
        case "lyric":
            lyricVerse = Int(attributes["number"] ?? "1") ?? 1
            lyricText = nil
            lyricSyllabic = .single
        case "dot":
            noteDots += 1
        case "rest":
            noteIsRest = true
            noteIsWholeMeasureRest = attributes["measure"] == "yes"
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement name: String,
                namespaceURI: String?, qualifiedName: String?) {
        defer {
            elements.removeLast()
            text = ""
        }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)

        switch name {
        case "bar-style":
            currentBarline?.style = value
        case "barline":
            if let barline = currentBarline { measureBarlines.append(barline) }
            currentBarline = nil
        case "work-title":
            let value = Self.cleaned(value)
            metadata.workTitle = value.isEmpty ? nil : value
        case "movement-title":
            let value = Self.cleaned(value)
            metadata.movementTitle = value.isEmpty ? nil : value
        case "movement-number":
            metadata.movementNumber = value.isEmpty ? nil : value
        case "rights":
            let value = Self.cleaned(value)
            metadata.rights = value.isEmpty ? nil : value
        case "software":
            let value = Self.cleaned(value)
            metadata.encodingSoftware = value.isEmpty ? nil : value
        case "creator":
            let creator = Self.cleaned(value)
            switch creatorType {
            case "composer": metadata.composer = creator.isEmpty ? nil : creator
            case "lyricist", "poet": metadata.lyricist = creator.isEmpty ? nil : creator
            default: break
            }
            creatorType = nil
        case "part-name":
            if let id = currentScorePartID, !value.isEmpty {
                // Part names carry embedded newlines: "Singstimme\nVoice".
                partNames[id] = Self.cleaned(value).split(whereSeparator: \.isNewline)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .joined(separator: ", ")
            }
        case "score-part":
            if let id = currentScorePartID { partOrder.append(id) }
            currentScorePartID = nil

        case "step":
            guard let step = Step(rawValue: value.uppercased()) else {
                fail(.invalidValue(element: "step", value: value), on: parser)
                return
            }
            noteStep = step
        case "alter":
            noteAlter = Int(value) ?? 0
        case "octave":
            guard let octave = Int(value) else {
                fail(.invalidValue(element: "octave", value: value), on: parser)
                return
            }
            noteOctave = octave
        case "duration":
            // <duration> appears inside <note>, <backup> and <forward> alike.
            if elements.dropLast().last == "backup" || elements.dropLast().last == "forward" {
                shiftDuration = Int(value)
            } else {
                noteDuration = Int(value)
            }
        case "backup":
            cursor = max(0, cursor - (shiftDuration ?? 0))
            shiftDuration = nil
        case "forward":
            cursor += shiftDuration ?? 0
            shiftDuration = nil
        case "type":
            noteType = NoteType(musicXML: value)
        case "voice":
            noteVoice = Int(value) ?? 1
        case "staff":
            // <staff> appears inside <note> and inside <direction> alike.
            if elements.dropLast().last == "direction" {
                directionStaff = Int(value)
            } else {
                noteStaff = Int(value) ?? 1
            }
        case "divisions":
            attributes.divisions = Int(value)
        case "fifths":
            keyFifths = Int(value)
        case "mode":
            keyMode = value.isEmpty ? nil : value
        case "beats":
            timeBeats = Int(value)
        case "beat-type":
            timeBeatType = Int(value)
        case "staves":
            attributes.staves = Int(value)
        case "key":
            if let fifths = keyFifths {
                attributes.key = KeySignature(fifths: fifths, mode: keyMode)
            }
        case "time":
            if let beats = timeBeats, let beatType = timeBeatType {
                attributes.time = TimeSignature(beats: beats, beatType: beatType)
            }
        case "words":
            // Exporters smuggle music-font glyphs into <words> as Private Use
            // codepoints. They mean nothing outside that font, and SPEC §6.1
            // forbids musical symbols in the output.
            // The untrimmed text, not `value`: a fragment's leading or trailing
            // space is what holds it apart from the next fragment.
            let cleaned = Self.cleaned(text)
            if !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pendingDirections.append(.words(cleaned))
            }
        case "rehearsal":
            let mark = Self.cleaned(value)
            if !mark.isEmpty { pendingDirections.append(.rehearsal(mark)) }
        case "beat-unit":
            if metronomeUnit == nil { metronomeUnit = value }
        case "per-minute":
            metronomePerMinute = value
        case "metronome":
            // A rate-less metronome is kept: the Webern writes its tempo as
            // "Langsam (", a metronome carrying only a beat unit, then " ca 48)",
            // and dropping the middle leaves the parenthesis dangling.
            if let unit = metronomeUnit {
                pendingDirections.append(.metronome(beatUnit: unit, dots: metronomeDots,
                                                    perMinute: metronomePerMinute ?? ""))
            }
        case "other-dynamics":
            let mark = Self.cleaned(value)
            if !mark.isEmpty { pendingDirections.append(.dynamic(mark)) }
        case "direction":
            // One <direction> is one thing to read, however many
            // <direction-type> elements the exporter split it across.
            if pendingDirections.count == 1 {
                events.append(.direction(PlacedDirection(
                    direction: pendingDirections[0],
                    staff: directionStaff ?? 1, onset: cursor)))
            } else if pendingDirections.count > 1 {
                events.append(.direction(PlacedDirection(
                    direction: .compound(pendingDirections),
                    staff: directionStaff ?? 1, onset: cursor)))
            }
            pendingDirections = []
            directionStaff = nil
        case "syllabic":
            lyricSyllabic = Syllabic(musicXML: value)
        case "text":
            // <text> appears only inside <lyric> in the MusicXML this reads.
            // Music-font glyphs turn up here as well as in <words>: the Satie
            // carries two Private Use codepoints as a lyric.
            lyricText = (lyricText ?? "") + Self.cleaned(value)
        case "lyric":
            if let text = lyricText, !text.isEmpty {
                noteLyrics.append(Lyric(verse: lyricVerse, text: text,
                                        syllabic: lyricSyllabic))
            }
            lyricText = nil
        case "accidental":
            notePrintedAccidental = Accidental(musicXML: value)
        case "actual-notes":
            tupletActual = Int(value)
        case "normal-notes":
            tupletNormal = Int(value)

        case "note":
            appendNote()
        case "measure":
            measures.append(Measure(number: measureNumber,
                                    isPickup: measureIsPickup,
                                    attributes: attributes.isEmpty ? nil : attributes,
                                    events: events,
                                    barlines: measureBarlines))
        case "part":
            if let id = currentPartID {
                parts.append(Part(id: id, name: partNames[id], measures: measures))
            }
            currentPartID = nil
        default:
            break
        }
    }

    /// Text from the file, made safe to speak without changing what it says.
    ///
    /// Three things happen, and nothing else — the words themselves are never
    /// rewritten, per `SPEC.md` §6.13:
    ///
    /// - **Private Use codepoints are dropped.** Exporters smuggle music-font
    ///   glyphs in as text; they mean nothing outside the font that defines them.
    /// - **Zero-width characters are dropped.** They are invisible to a reader
    ///   and to trimming alike.
    /// - **Unusual spaces become ordinary ones.** French typography puts a
    ///   non-breaking space before "!" and ":", which is the same character
    ///   semantically but invisible to whitespace trimming.
    static func cleaned(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0xE000...0xF8FF, 0xF0000...0xFFFFD, 0x100000...0x10FFFD:
                continue                                   // private use
            case 0x200B...0x200F, 0xFEFF, 0x2060:
                continue                                   // zero width
            case 0x00A0, 0x2000...0x200A, 0x202F, 0x205F, 0x3000:
                scalars.append(" ")                        // unusual spaces
            default:
                scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    /// Records a fatal problem and stops parsing. `didEndElement`'s `defer` still
    /// runs, so the element stack stays consistent.
    private func fail(_ error: TranscriptionError, on parser: XMLParser) {
        if failure == nil { failure = error }
        parser.abortParsing()
    }

    // MARK: - Building

    private func resetNote() {
        noteStep = nil
        noteAlter = 0
        noteOctave = nil
        noteDuration = nil
        noteType = nil
        noteIsRest = false
        noteIsWholeMeasureRest = false
        noteVoice = 1
        noteStaff = 1
        noteDots = 0
        noteIsChordMember = false
        noteIsGrace = false
        notePrintedAccidental = nil
        tupletActual = nil
        tupletNormal = nil
        noteLyrics = []
        noteTie = TieState()
        noteSlur = SlurState()
        noteArticulations = []
        noteOrnaments = []
        noteIsArpeggiated = false
        noteHasFermata = false
        noteIsCue = false
        lyricText = nil
        lyricSyllabic = .single
    }

    private func appendNote() {
        // A chord member sounds with the note before it, so it shares that onset
        // and does not advance the cursor. A grace note has no duration at all.
        let onset = noteIsChordMember ? lastOnset : cursor
        if !noteIsChordMember && !noteIsGrace {
            lastOnset = cursor
            cursor += noteDuration ?? 0
        }

        var tuplet: Tuplet?
        if let actual = tupletActual, let normal = tupletNormal {
            tuplet = Tuplet(actual: actual, normal: normal)
        }
        let duration = Duration(divisions: noteDuration ?? 0, type: noteType,
                                dots: noteDots, tuplet: tuplet)
        if noteIsRest {
            events.append(.rest(Rest(duration: duration,
                                     isWholeMeasure: noteIsWholeMeasureRest,
                                     voice: noteVoice, staff: noteStaff,
                                     onset: onset)))
            return
        }
        guard let step = noteStep, let octave = noteOctave else { return }
        events.append(.note(Note(
            pitch: Pitch(step: step, alter: noteAlter, octave: octave),
            duration: duration, voice: noteVoice, staff: noteStaff,
            isChordMember: noteIsChordMember, isGrace: noteIsGrace,
            printedAccidental: notePrintedAccidental, onset: onset,
            lyrics: noteLyrics.sorted { $0.verse < $1.verse },
            tie: noteTie, slur: noteSlur, articulations: noteArticulations,
            ornaments: noteOrnaments, isArpeggiated: noteIsArpeggiated,
            hasFermata: noteHasFermata, isCue: noteIsCue)))
    }
}
