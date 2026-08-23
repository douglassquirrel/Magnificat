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
    private var directionStaff: Int?
    /// Whether the hairpin currently open is a crescendo, so its stop can name it.
    private var openWedgeIsCrescendo = true
    private var metronomeUnit: String?
    private var metronomeDots = 0
    private var metronomePerMinute: String?
    private var pendingDirections: [Direction] = []
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
        case "work-title":
            metadata.workTitle = value.isEmpty ? nil : value
        case "movement-title":
            metadata.movementTitle = value.isEmpty ? nil : value
        case "movement-number":
            metadata.movementNumber = value.isEmpty ? nil : value
        case "rights":
            metadata.rights = value.isEmpty ? nil : value
        case "software":
            metadata.encodingSoftware = value.isEmpty ? nil : value
        case "creator":
            switch creatorType {
            case "composer": metadata.composer = value.isEmpty ? nil : value
            case "lyricist", "poet": metadata.lyricist = value.isEmpty ? nil : value
            default: break
            }
            creatorType = nil
        case "part-name":
            if let id = currentScorePartID, !value.isEmpty {
                // Part names carry embedded newlines: "Singstimme\nVoice".
                partNames[id] = value.split(whereSeparator: \.isNewline)
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
            if !value.isEmpty { pendingDirections.append(.words(value)) }
        case "rehearsal":
            if !value.isEmpty { pendingDirections.append(.rehearsal(value)) }
        case "beat-unit":
            if metronomeUnit == nil { metronomeUnit = value }
        case "per-minute":
            metronomePerMinute = value
        case "metronome":
            if let unit = metronomeUnit, let rate = metronomePerMinute, !rate.isEmpty {
                pendingDirections.append(.metronome(beatUnit: unit, dots: metronomeDots,
                                                    perMinute: rate))
            }
        case "other-dynamics":
            if !value.isEmpty { pendingDirections.append(.dynamic(value)) }
        case "direction":
            for direction in pendingDirections {
                events.append(.direction(PlacedDirection(
                    direction: direction, staff: directionStaff ?? 1, onset: cursor)))
            }
            pendingDirections = []
            directionStaff = nil
        case "syllabic":
            lyricSyllabic = Syllabic(musicXML: value)
        case "text":
            // <text> appears only inside <lyric> in the MusicXML this reads.
            lyricText = (lyricText ?? "") + value
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
                                    events: events))
        case "part":
            if let id = currentPartID {
                parts.append(Part(id: id, name: partNames[id], measures: measures))
            }
            currentPartID = nil
        default:
            break
        }
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
            lyrics: noteLyrics.sorted { $0.verse < $1.verse })))
    }
}
