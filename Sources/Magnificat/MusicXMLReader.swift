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
        self = handler.makeScore()
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
    private var partOrder: [String] = []
    private var partNames: [String: String] = [:]
    private var currentScorePartID: String?

    // The part being read.
    private var currentPartID: String?
    private var measures: [Measure] = []
    private var parts: [Part] = []

    // The measure being read.
    private var measureNumber = ""
    private var events: [MusicalEvent] = []

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
    private var tupletActual: Int?
    private var tupletNormal: Int?

    func makeScore() -> Score {
        Score(parts: parts)
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
        case "part":
            currentPartID = attributes["id"]
            measures = []
        case "measure":
            measureNumber = attributes["number"] ?? ""
            events = []
        case "note":
            resetNote()
        case "chord":
            noteIsChordMember = true
        case "grace":
            noteIsGrace = true
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
            noteStep = Step(rawValue: value.uppercased())
        case "alter":
            noteAlter = Int(value) ?? 0
        case "octave":
            noteOctave = Int(value)
        case "duration":
            noteDuration = Int(value)
        case "type":
            noteType = NoteType(musicXML: value)
        case "voice":
            noteVoice = Int(value) ?? 1
        case "staff":
            noteStaff = Int(value) ?? 1
        case "accidental":
            notePrintedAccidental = Accidental(musicXML: value)
        case "actual-notes":
            tupletActual = Int(value)
        case "normal-notes":
            tupletNormal = Int(value)

        case "note":
            appendNote()
        case "measure":
            measures.append(Measure(number: measureNumber, events: events))
        case "part":
            if let id = currentPartID {
                parts.append(Part(id: id, name: partNames[id], measures: measures))
            }
            currentPartID = nil
        default:
            break
        }
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
    }

    private func appendNote() {
        var tuplet: Tuplet?
        if let actual = tupletActual, let normal = tupletNormal {
            tuplet = Tuplet(actual: actual, normal: normal)
        }
        let duration = Duration(divisions: noteDuration ?? 0, type: noteType,
                                dots: noteDots, tuplet: tuplet)
        if noteIsRest {
            events.append(.rest(Rest(duration: duration,
                                     isWholeMeasure: noteIsWholeMeasureRest,
                                     voice: noteVoice, staff: noteStaff)))
            return
        }
        guard let step = noteStep, let octave = noteOctave else { return }
        events.append(.note(Note(
            pitch: Pitch(step: step, alter: noteAlter, octave: octave),
            duration: duration, voice: noteVoice, staff: noteStaff,
            isChordMember: noteIsChordMember, isGrace: noteIsGrace,
            printedAccidental: notePrintedAccidental)))
    }
}
