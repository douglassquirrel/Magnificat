extension Score {
    /// Every coherence problem in the score, in part then measure order.
    /// See `SPEC.md` §6.15.
    func coherenceAnomalies() -> [Anomaly] {
        var anomalies: [Anomaly] = []

        for part in parts {
            var divisions: Int?
            var time: TimeSignature?
            var declaredStaves = 1

            for measure in part.measures {
                if let stated = measure.attributes?.divisions { divisions = stated }
                if let stated = measure.attributes?.time { time = stated }
                if let stated = measure.attributes?.staves { declaredStaves = stated }

                anomalies += Self.staffProblems(in: measure, part: part,
                                                declaredStaves: declaredStaves)
                if let divisions {
                    anomalies += Self.durationProblems(in: measure, part: part,
                                                       divisions: divisions)
                }
                // A pickup is short by definition, and with no meter there is
                // nothing to check against.
                if let divisions, let time, !measure.isPickup {
                    anomalies += Self.lengthProblems(in: measure, part: part,
                                                     divisions: divisions, time: time)
                }
            }
        }
        return anomalies
    }

    private static func staffProblems(in measure: Measure, part: Part,
                                      declaredStaves: Int) -> [Anomaly] {
        let offenders = Set(measure.events.map(\.staff).filter { $0 > declaredStaves })
        return offenders.sorted().map { staff in
            Anomaly(kind: .staffOutOfRange, partID: part.id,
                    measureNumber: measure.number,
                    detail: "a note is written on staff \(staff), but this part "
                          + "declares \(declaredStaves)")
        }
    }

    private static func durationProblems(in measure: Measure, part: Part,
                                         divisions: Int) -> [Anomaly] {
        var anomalies: [Anomaly] = []
        for event in measure.events {
            guard case .note(let note) = event, !note.isGrace else { continue }
            guard let type = note.duration.type else { continue }
            // A tuplet's duration is modified on purpose; that is not a conflict.
            guard note.duration.tuplet == nil else { continue }

            let expected = Duration.divisionsFor(type: type, dots: note.duration.dots,
                                                 perQuarter: divisions)
            guard let expected, expected != note.duration.divisions else { continue }
            anomalies.append(Anomaly(
                kind: .durationContradictsType, partID: part.id,
                measureNumber: measure.number,
                detail: "a note typed \(note.duration.spokenName) lasts "
                      + "\(note.duration.divisions) divisions, where that value "
                      + "would be \(expected)"))
        }
        return anomalies
    }

    private static func lengthProblems(in measure: Measure, part: Part,
                                       divisions: Int, time: TimeSignature) -> [Anomaly] {
        // A measure lasts beats * (4 / beat-type) quarter notes.
        guard time.beatType > 0 else { return [] }
        let expected = time.beats * divisions * 4 / time.beatType

        var anomalies: [Anomaly] = []
        for voice in Set(measure.events.map(\.voice)).sorted() where voice != 0 {
            let events = measure.events.filter { $0.voice == voice }
            // A whole-measure rest is as long as the measure by definition.
            if events.contains(where: { if case .rest(let r) = $0 { return r.isWholeMeasure }
                                        return false }) { continue }

            // Where the voice ends, not the sum of its durations. <forward> skips
            // time without producing an event, so a voice that rests by skipping
            // rather than by writing rests would look short if durations were
            // simply added up. Chord members share their lead's onset, so taking
            // the furthest end point handles them too.
            let total = events.reduce(0) { furthest, event in
                let end: Int
                switch event {
                case .note(let note):
                    end = note.isGrace ? note.onset : note.onset + note.duration.divisions
                case .rest(let rest):
                    end = rest.onset + rest.duration.divisions
                case .direction:
                    end = 0
                }
                return max(furthest, end)
            }
            // Only an **overfull** bar is reported. A short bar is routine in
            // correct music — a pickup, the bar before a repeat, the bar closing
            // a first ending — and telling them apart from errors would need the
            // repeat structure modelled, which is out of scope. Measured on the
            // Davies, where bars 6 and 7 hold 12 and 4 divisions and sum to a
            // full 16 across a repeat barline: flagging short bars fired on
            // correct music, which trains a reader to ignore anomalies.
            guard total > expected else { continue }
            anomalies.append(Anomaly(
                kind: .measureDurationMismatch, partID: part.id,
                measureNumber: measure.number,
                detail: "voice \(voice) holds \(total) divisions, more than the "
                      + "\(expected) that \(time.beats)/\(time.beatType) allows"))
        }
        return anomalies
    }
}

extension Duration {
    /// How long `type` with `dots` lasts, in divisions, or `nil` when it cannot be
    /// expressed exactly at this divisions value.
    static func divisionsFor(type: NoteType, dots: Int, perQuarter: Int) -> Int? {
        guard perQuarter > 0, dots >= 0, dots < 8 else { return nil }
        let dotNumerator = (1 << (dots + 1)) - 1
        let dotDenominator = 1 << dots
        let numerator = perQuarter * type.quartersNumerator * dotNumerator
        let denominator = type.quartersDenominator * dotDenominator
        guard denominator != 0, numerator % denominator == 0 else { return nil }
        return numerator / denominator
    }
}
