extension Renderer {
    /// The heading block: one fact per line, omitting what the file does not
    /// carry. See `SPEC.md` §6.13.
    func heading(for score: Score) -> [TranscriptLine] {
        var facts: [String] = []
        let metadata = score.metadata

        // The movement title names this piece; the work title names the
        // collection it sits in, and is given separately below.
        let title = metadata.movementTitle ?? metadata.workTitle
        if let title { facts.append(title) }
        if let composer = metadata.composer { facts.append(composer) }
        if let lyricist = metadata.lyricist { facts.append("Words by \(lyricist)") }

        if let work = metadata.workTitle, metadata.movementTitle != nil {
            // Used exactly as written. Every fixture that carries an opus number
            // has it inside the title already, so <work-number> is not spoken —
            // it would give "3 Lieder, Op.7, opus 7".
            if let number = metadata.movementNumber {
                facts.append("From \(work), number \(number)")
            } else {
                facts.append("From \(work)")
            }
        }

        let names = score.parts.enumerated().map { Self.name(of: $1, at: $0) }
        facts.append("\(count(names.count, "part")): \(names.joined(separator: "; "))")

        let measures = score.parts.map(\.measures.count).max() ?? 0
        facts.append(count(measures, "measure"))

        if let key = score.firstKey { facts.append("Key: \(key.spokenName)") }
        if let time = score.firstTime {
            facts.append("Time signature: \(time.beats) \(time.beatType)")
        } else {
            // The absence of a meter is information, not a default of 4/4.
            facts.append("No time signature.")
        }

        return facts.map { TranscriptLine(text: $0, kind: .scoreHeading) }
    }

    /// "1 part", "2 parts" — singular where it matters, which is often.
    private func count(_ n: Int, _ noun: String) -> String {
        n == 1 ? "1 \(noun)" : "\(n) \(noun)s"
    }
}

extension Score {
    /// The first key signature stated anywhere, in part then measure order.
    var firstKey: KeySignature? {
        parts.lazy.flatMap(\.measures).compactMap { $0.attributes?.key }.first
    }

    /// The first time signature stated anywhere. `nil` when the score has none
    /// at all, which the Parry in the fixtures does not.
    var firstTime: TimeSignature? {
        parts.lazy.flatMap(\.measures).compactMap { $0.attributes?.time }.first
    }
}
