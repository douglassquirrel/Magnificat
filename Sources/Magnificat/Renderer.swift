extension Score {
    /// Renders the score as linear plain text.
    ///
    /// This never throws: any score that parsed can be rendered. Musical
    /// incoherence is reported rather than refused. See `SPEC.md` §5.
    public func transcript(options: TranscriptOptions = TranscriptOptions()) -> Transcript {
        Renderer(options: options).render(self)
    }
}

/// Turns a parsed score into transcript lines. All the English lives here; the
/// score model has none in it. See `SPEC.md` §4.
struct Renderer {
    let options: TranscriptOptions

    /// One readable line of music: a staff, and one voice on it.
    struct Stream: Equatable {
        var label: String
        var staff: Int
        var voice: Int
        /// True for the first voice of its staff, which is where directions are
        /// spoken so they are heard once rather than once per voice.
        var carriesDirections: Bool = false
    }

    func render(_ score: Score) -> Transcript {
        let anomalies = score.coherenceAnomalies()
        switch options.layout {
        case .byPart:
            return Transcript(lines: heading(for: score) + byPart(score),
                              anomalies: anomalies)
        case .byMeasure:
            var missing: [Anomaly] = []
            let lines = byMeasure(score, missing: &missing)
            return Transcript(lines: heading(for: score) + lines,
                              anomalies: anomalies + missing)
        }
    }

    /// The whole of one stream, then the whole of the next. The commonest task is
    /// learning one line, so this is the default. See `SPEC.md` §6.7.
    private func byPart(_ score: Score) -> [TranscriptLine] {
        var lines: [TranscriptLine] = []
        for (index, part) in score.parts.enumerated() {
            let name = Self.name(of: part, at: index)
            lines.append(TranscriptLine(text: name, kind: .partHeading, partID: part.id))

            // Pitch names are settled for the whole part before any stream is
            // rendered. An accidental is in force across every voice and staff of
            // the part until the barline (SPEC.md §6.2), and streams are rendered
            // one after another, so the state cannot follow the rendering order.
            let names = spokenNames(for: part)

            let streams = Self.streams(of: part, partName: name)
            for stream in streams {
                // Not when the label is the part name again: a single-staff part
                // with a second voice would otherwise print its name twice in a
                // row, which the Parry golden did.
                if streams.count > 1 && stream.label != name {
                    lines.append(TranscriptLine(text: stream.label, kind: .partHeading,
                                                partID: part.id))
                }
                lines += renderMeasures(of: part, stream: stream, names: names)
            }
            lines += Self.lyricsSummary(of: part)
        }
        return lines
    }

    /// Measure 1 of every stream, then measure 2 — for fitting the parts together.
    ///
    /// Every line names its stream, because a reader stepping through cannot
    /// otherwise tell whose line they are on. See `SPEC.md` §6.7.
    private func byMeasure(_ score: Score, missing: inout [Anomaly]) -> [TranscriptLine] {
        // Render each stream once, then interleave what came out.
        var rendered: [(part: Part, stream: Stream, byNumber: [String: [TranscriptLine]])] = []
        var order: [String] = []

        for (index, part) in score.parts.enumerated() {
            let name = Self.name(of: part, at: index)
            let names = spokenNames(for: part)
            for measure in part.measures where !order.contains(measure.number) {
                order.append(measure.number)
            }
            for stream in Self.streams(of: part, partName: name) {
                let lines = renderMeasures(of: part, stream: stream, names: names)
                rendered.append((part, stream,
                                 Dictionary(grouping: lines) { $0.measureNumber ?? "" }))
            }
        }

        var lines: [TranscriptLine] = []
        for number in order {
            lines.append(TranscriptLine(text: "Measure \(number)", kind: .measure,
                                        measureNumber: number))
            for entry in rendered {
                guard let measureLines = entry.byNumber[number] else {
                    // A stream that has no such measure is announced. OMR output is
                    // often ragged, and silence would read as a bar of rest, which
                    // is a different piece of music.
                    lines.append(TranscriptLine(
                        text: "\(entry.stream.label) has no measure \(number).",
                        kind: .measure, partID: entry.part.id, measureNumber: number))
                    missing.append(Anomaly(
                        kind: .missingMeasureInPart, partID: entry.part.id,
                        measureNumber: number,
                        detail: "\(entry.stream.label) has no measure \(number)"))
                    continue
                }
                for line in measureLines {
                    let body = Self.withoutMeasurePrefix(line.text, number)
                    lines.append(TranscriptLine(
                        text: body.isEmpty ? entry.stream.label
                                           : "\(entry.stream.label). \(body)",
                        kind: line.kind, partID: line.partID, measureNumber: number))
                }
            }
        }
        return lines
    }

    /// Strips the "Measure 5. " that byPart lines carry: under .byMeasure the
    /// number is already on its own line above.
    static func withoutMeasurePrefix(_ text: String, _ number: String) -> String {
        let prefix = "Measure \(number). "
        if text.hasPrefix(prefix) { return String(text.dropFirst(prefix.count)) }
        if text == "Measure \(number)" { return "" }
        return text
    }

    // MARK: - Naming parts and streams

    /// The part's name, or its position when the file gives none. Blank part
    /// names are the norm in machine-generated MusicXML. See `SPEC.md` §6.6.
    static func name(of part: Part, at index: Int) -> String {
        if let name = part.name, !name.isEmpty { return name }
        return "Part \(index + 1)"
    }

    /// The streams of a part: every voice on every staff that carries events.
    ///
    /// Hands are named only where the file says the part has two staves.
    /// Machine-generated files split a grand staff into two one-staff parts, and
    /// nothing marks the pair as one instrument, so this never guesses.
    static func streams(of part: Part, partName: String) -> [Stream] {
        // Streams are discovered from notes and rests only. A direction has no
        // voice of its own, and letting it contribute one would invent a phantom
        // stream carrying nothing but directions.
        let events = part.measures.flatMap(\.events).filter { event in
            if case .direction = event { return false }
            return true
        }
        let declaredStaves = part.measures.compactMap { $0.attributes?.staves }.max()
        let staffCount = max(declaredStaves ?? 1, events.map(\.staff).max() ?? 1)

        var result: [Stream] = []
        for staff in Set(events.map(\.staff)).sorted() {
            let base: String
            if staffCount == 1 {
                base = partName
            } else if staff == 1 {
                base = "Right hand"
            } else if staff == 2 {
                base = "Left hand"
            } else {
                base = "Staff \(staff)"
            }

            let voices = Set(events.filter { $0.staff == staff }.map(\.voice)).sorted()
            for (position, voice) in voices.enumerated() {
                // Numbered by position on the staff, not by MusicXML's voice
                // number: a piano left hand uses voices 5 and 6, and "voice 6"
                // would mean nothing to a reader.
                let label = position == 0 ? base : "\(base), voice \(position + 1)"
                result.append(Stream(label: label, staff: staff, voice: voice,
                                     carriesDirections: position == 0))
            }
        }
        return result
    }

    // MARK: - Pitch names, settled per part

    /// The spoken name of every note of every measure, indexed the same way the
    /// measures' events are. Rests get an empty string, which is never read.
    private func spokenNames(for part: Part) -> [[String]] {
        var context = AccidentalContext(key: KeySignature(fifths: 0),
                                        style: options.accidentalStyle)
        var byMeasure: [[String]] = []

        for measure in part.measures {
            if let key = measure.attributes?.key { context.key = key }
            context.startNewMeasure()

            byMeasure.append(measure.events.map { event in
                guard case .note(let note) = event else { return "" }
                return context.spokenName(of: note.pitch,
                                          printedAccidental: note.printedAccidental)
            })
        }
        return byMeasure
    }

    // MARK: - Measures

    private func renderMeasures(of part: Part, stream: Stream,
                                names: [[String]]) -> [TranscriptLine] {
        var lines: [TranscriptLine] = []
        // A backward repeat says only "go back"; the measure it returns to is the
        // last forward repeat, or the start of the part when there is none.
        var repeatTarget = part.measures.first?.number ?? "1"

        /// A measure's content, held back so a run of empty bars can be collapsed.
        struct Rendered {
            var measure: Measure
            var opening: [String]
            var groups: [EventGroup]
            var closing: [String]
            /// True when the bar holds a whole-measure rest and nothing else at
            /// all — no dynamic, no repeat, nothing worth stopping for.
            var isBareWholeMeasureRest: Bool
        }
        var pending: [Rendered] = []

        for (index, measure) in part.measures.enumerated() {
            if measure.barlines.contains(where: { $0.repeatDirection == .forward }) {
                repeatTarget = measure.number
            }
            let spoken = names[index]
            let items = measure.events.indices.compactMap { position -> Item? in
                let event = measure.events[position]
                guard event.staff == stream.staff else { return nil }
                if case .direction = event {
                    guard stream.carriesDirections else { return nil }
                } else {
                    guard event.voice == stream.voice else { return nil }
                }
                return Item(event: event, spokenPitch: spoken[position])
            }

            // A stream is silent in most measures when it is a secondary voice.
            // A bare "Measure 4." would say nothing, and a reader stepping
            // through the stream would meet dozens of them.
            guard !items.isEmpty else { continue }

            let groups = Self.group(items)
            // Barlines and the pickup marker belong to the measure, not to any one
            // stream, so only the stream that carries directions speaks them.
            let opening = stream.carriesDirections
                ? (measure.isPickup ? ["Pickup measure"] : [])
                    + measure.barlines.filter { $0.location == .left }
                        .flatMap { $0.spokenPhrases(repeatTarget: repeatTarget) }
                : []
            let closing = stream.carriesDirections
                ? measure.barlines.filter { $0.location == .right }
                    .flatMap { $0.spokenPhrases(repeatTarget: repeatTarget) }
                : []

            var isBare = false
            if case .rest(let rest)? = groups.first, groups.count == 1,
               rest.isWholeMeasure, opening.isEmpty, closing.isEmpty {
                isBare = true
            }
            pending.append(Rendered(measure: measure, opening: opening, groups: groups,
                                    closing: closing, isBareWholeMeasureRest: isBare))
        }

        // Collapse runs of empty bars. Only under .byPart: .byMeasure interleaves
        // the streams measure by measure, and a collapsed span has no single
        // measure to interleave at.
        let collapsing = options.layout == .byPart
        var index = 0
        while index < pending.count {
            let entry = pending[index]
            if collapsing && entry.isBareWholeMeasureRest {
                var last = index
                while last + 1 < pending.count && pending[last + 1].isBareWholeMeasureRest {
                    last += 1
                }
                if last > index {
                    let first = pending[index].measure.number
                    let final = pending[last].measure.number
                    lines.append(TranscriptLine(
                        text: "Measures \(first) to \(final). Rest.",
                        kind: .measure, partID: part.id, measureNumber: first))
                    index = last + 1
                    continue
                }
            }

            let measure = entry.measure
            let opening = entry.opening
            let groups = entry.groups
            let closing = entry.closing
            index += 1

            switch options.density {
            case .perMeasure:
                let text = (["Measure \(measure.number)"] + opening
                            + groups.map { phrase(for: $0) } + closing)
                    .map { Self.punctuated($0) }
                    .joined(separator: " ")
                lines.append(TranscriptLine(text: text, kind: .measure,
                                            partID: part.id,
                                            measureNumber: measure.number))

            case .perEvent:
                lines.append(TranscriptLine(text: "Measure \(measure.number)",
                                            kind: .measure, partID: part.id,
                                            measureNumber: measure.number))
                for phrase in opening {
                    lines.append(TranscriptLine(text: phrase, kind: .event,
                                                partID: part.id,
                                                measureNumber: measure.number))
                }
                for group in groups {
                    lines.append(TranscriptLine(text: phrase(for: group, withLyrics: false),
                                                kind: .event, partID: part.id,
                                                measureNumber: measure.number))
                    // A lyric gets its own line so a singer can step word by word.
                    for lyric in Self.lyrics(of: group) {
                        let prefix = lyric.verse == 1
                            ? "Lyric: " : "Verse \(lyric.verse) lyric: "
                        lines.append(TranscriptLine(text: prefix + lyric.hyphenated,
                                                    kind: .event, partID: part.id,
                                                    measureNumber: measure.number))
                    }
                }
                for phrase in closing {
                    lines.append(TranscriptLine(text: phrase, kind: .event,
                                                partID: part.id,
                                                measureNumber: measure.number))
                }
            }
        }
        return lines
    }

    /// An event paired with the pitch name already settled for it.
    struct Item {
        var event: MusicalEvent
        var spokenPitch: String
    }

    /// Notes that sound together, or a rest. Chord members are gathered here so
    /// the renderer never has to think about `<chord/>` again.
    enum EventGroup {
        case notes([(note: Note, spoken: String)])
        case rest(Rest)
        case direction(Direction)
    }

    /// Gathers chord members onto the note they sound with. See `SPEC.md` §6.5.
    static func group(_ items: [Item]) -> [EventGroup] {
        var groups: [EventGroup] = []
        for item in items {
            switch item.event {
            case .note(let note):
                let entry = (note: note, spoken: item.spokenPitch)
                if note.isChordMember, case .notes(let sounding)? = groups.last {
                    groups[groups.count - 1] = .notes(sounding + [entry])
                } else {
                    groups.append(.notes([entry]))
                }
            case .rest(let rest):
                groups.append(.rest(rest))
            case .direction(let placed):
                groups.append(.direction(placed.direction))
            }
        }
        return groups
    }

    /// The lyrics attached to a group, if any.
    static func lyrics(of group: EventGroup) -> [Lyric] {
        guard case .notes(let sounding) = group else { return [] }
        return sounding[0].note.lyrics
    }

    /// One group, spoken. No trailing full stop: the caller punctuates.
    private func phrase(for group: EventGroup, withLyrics: Bool = true) -> String {
        switch group {
        case .direction(let direction):
            return direction.spokenText
        case .rest(let rest):
            if rest.isWholeMeasure { return "Whole measure rest" }
            return "\(rest.duration.spokenName.capitalizedFirst) rest"

        case .notes(let sounding):
            // Low to high by sounding pitch, whatever order the file wrote them in.
            let ordered = sounding.sorted {
                $0.note.pitch.chromaticValue < $1.note.pitch.chromaticValue
            }
            let names = ordered.map(\.spoken)
            // The duration belongs to the chord as a whole; take it from the note
            // the file wrote first, which is the one that carries the timing.
            let duration = sounding[0].note.duration.spokenName
            let lead = sounding[0].note
            var head = names.count == 1
                ? "\(names[0]), \(duration)"
                : "Chord \(names.joined(separator: ", ")), \(duration)"
            // Grace and cue notes are prefixed rather than suffixed: a reader
            // needs to know what kind of note it is before hearing the pitch.
            if lead.isGrace { head = "Grace note: " + head }
            if lead.isCue { head = "Cue note: " + head }
            head += Self.notationPhrase(for: lead, chord: sounding.map(\.note))
            // Lyrics belong to the note the file wrote first; a chord is sung on
            // one syllable, not one per note.
            return withLyrics ? head + Self.lyricPhrase(sounding[0].note.lyrics) : head
        }
    }
}

extension Renderer {
    /// A phrase with the full stop that separates it from the next — unless it
    /// already ends in punctuation of its own.
    ///
    /// Lyrics carry the poem's punctuation, and a direction may be written
    /// "poco rit."; appending another stop gave "lyric -ne,." and "poco rit..",
    /// which a screen reader reads as two marks running together.
    static func punctuated(_ phrase: String) -> String {
        guard let last = phrase.last else { return phrase }
        return ".,!?;:".contains(last) ? phrase : phrase + "."
    }

    /// Each verse of a part given again as continuous running text, so the words
    /// can be read as words rather than one syllable per note. See `SPEC.md` §6.11.
    static func lyricsSummary(of part: Part) -> [TranscriptLine] {
        var byVerse: [Int: [Lyric]] = [:]
        for measure in part.measures {
            for event in measure.events {
                guard case .note(let note) = event else { continue }
                for lyric in note.lyrics { byVerse[lyric.verse, default: []].append(lyric) }
            }
        }
        guard !byVerse.isEmpty else { return [] }

        var lines = [TranscriptLine(text: "Lyrics", kind: .lyricsSummary, partID: part.id)]
        for verse in byVerse.keys.sorted() {
            var text = ""
            for lyric in byVerse[verse] ?? [] {
                // A syllable that continues into the next joins it without a
                // space; anything else starts a new word.
                if !text.isEmpty && !lyric.syllabic.continuesFromPrevious {
                    text += " "
                }
                text += lyric.text
            }
            lines.append(TranscriptLine(text: "Verse \(verse): \(text)",
                                        kind: .lyricsSummary, partID: part.id))
        }
        return lines
    }

    /// The notations attached to a note, in the fixed order `SPEC.md` §6.10 sets:
    /// tie, slur, articulations, ornament, arpeggio, fermata.
    static func notationPhrase(for note: Note, chord: [Note]) -> String {
        var parts: [String] = []
        if note.tie.stops { parts.append("tied from previous") }
        if note.tie.starts { parts.append("tied") }
        if note.slur.ends { parts.append("slur ends") }
        if note.slur.begins { parts.append("slur begins") }
        parts += note.articulations.map(\.spokenWord)
        parts += note.ornaments.map(\.spokenWord)
        // Any note of a chord may carry the arpeggio or fermata mark.
        if chord.contains(where: \.isArpeggiated) { parts.append("arpeggiated") }
        if chord.contains(where: \.hasFermata) { parts.append("fermata") }
        return parts.map { ", " + $0 }.joined()
    }

    /// The lyrics of a note, appended to its phrase. No quotation marks: many
    /// screen readers announce them. See `SPEC.md` §6.1 and §6.11.
    static func lyricPhrase(_ lyrics: [Lyric]) -> String {
        lyrics.map { lyric in
            lyric.verse == 1
                ? ", lyric \(lyric.hyphenated)"
                : ", verse \(lyric.verse) lyric \(lyric.hyphenated)"
        }.joined()
    }
}

extension String {
    /// Uppercases only the first character, leaving the rest alone. Unlike
    /// `capitalized`, this does not lowercase anything or touch later words.
    var capitalizedFirst: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}
