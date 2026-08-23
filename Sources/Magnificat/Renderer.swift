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
    }

    func render(_ score: Score) -> Transcript {
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
                if streams.count > 1 {
                    lines.append(TranscriptLine(text: stream.label, kind: .partHeading,
                                                partID: part.id))
                }
                lines += renderMeasures(of: part, stream: stream, names: names)
            }
        }
        return Transcript(lines: lines)
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
        let events = part.measures.flatMap(\.events)
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
                result.append(Stream(label: label, staff: staff, voice: voice))
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

        for (index, measure) in part.measures.enumerated() {
            let spoken = names[index]
            let items = measure.events.indices.compactMap { position -> Item? in
                let event = measure.events[position]
                guard event.staff == stream.staff, event.voice == stream.voice else {
                    return nil
                }
                return Item(event: event, spokenPitch: spoken[position])
            }

            let phrases = Self.group(items).map(phrase(for:))
            let text = (["Measure \(measure.number)"] + phrases)
                .map { $0 + "." }
                .joined(separator: " ")
            lines.append(TranscriptLine(text: text, kind: .measure,
                                        partID: part.id, measureNumber: measure.number))
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
            }
        }
        return groups
    }

    /// One group, spoken. No trailing full stop: the caller punctuates.
    private func phrase(for group: EventGroup) -> String {
        switch group {
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
            if names.count == 1 { return "\(names[0]), \(duration)" }
            return "Chord \(names.joined(separator: ", ")), \(duration)"
        }
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
