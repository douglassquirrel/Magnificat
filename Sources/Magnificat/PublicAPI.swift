import Foundation

/// How a caller picks out a part.
///
/// Selection by index must exist: machine-generated MusicXML gives parts blank
/// names and 32-character hash IDs, so a name is often no handle at all.
/// See `SPEC.md` §5.
public enum PartSelector: Sendable, Equatable {
    /// By position in the score, 1-based.
    case index(Int)
    /// By `<part-name>`, falling back to the part ID.
    case named(String)
}

/// Cheap metadata for a file picker or a "what is this?" screen, without
/// rendering a transcript. See `SPEC.md` §5.
public struct ScoreSummary: Sendable, Equatable {
    public var title: String?
    public var composer: String?
    public var lyricist: String?
    /// Part names in document order, with positional fallbacks applied.
    public var partNames: [String]
    /// The longest part's measure count.
    public var measureCount: Int
    /// The opening key signature, if the score states one.
    public var key: KeySignature?
    /// The opening time signature. `nil` when the score has none at all.
    public var time: TimeSignature?
    /// True when any note carries a syllable.
    public var hasLyrics: Bool
    /// How many verses the score carries.
    public var verseCount: Int
}

extension Score {
    /// A summary of the score, without rendering it.
    public var summary: ScoreSummary {
        let notes = parts.lazy.flatMap(\.measures).flatMap(\.events).compactMap { event -> Note? in
            guard case .note(let note) = event else { return nil }
            return note
        }
        let verses = Set(notes.flatMap { $0.lyrics.map(\.verse) })

        return ScoreSummary(
            title: metadata.movementTitle ?? metadata.workTitle,
            composer: metadata.composer,
            lyricist: metadata.lyricist,
            partNames: parts.enumerated().map { Renderer.name(of: $1, at: $0) },
            measureCount: parts.map(\.measures.count).max() ?? 0,
            key: firstKey,
            time: firstTime,
            hasLyrics: !verses.isEmpty,
            verseCount: verses.count)
    }

    /// Renders a subset of the score — one singer's line, or bars 40 to 56 for
    /// practice.
    ///
    /// - Parameters:
    ///   - options: the rendering knobs.
    ///   - parts: which parts to include, or `nil` for all.
    ///   - measures: which measures to include, matched against the numbers as
    ///     printed, or `nil` for all.
    /// - Throws: ``TranscriptionError/unknownPart(_:)`` or
    ///   ``TranscriptionError/measureRangeOutOfBounds(requested:available:)``.
    public func transcript(options: TranscriptOptions = TranscriptOptions(),
                           parts selectors: [PartSelector]? = nil,
                           measures: ClosedRange<Int>? = nil) throws -> Transcript {
        var subset = self

        if let selectors {
            var chosen: [Part] = []
            for selector in selectors {
                guard let part = part(for: selector) else {
                    throw TranscriptionError.unknownPart(Self.describe(selector))
                }
                if !chosen.contains(where: { $0.id == part.id }) { chosen.append(part) }
            }
            subset.parts = chosen
        }

        if let measures {
            let numbered = subset.parts.flatMap(\.measures).compactMap { Int($0.number) }
            guard let lowest = numbered.min(), let highest = numbered.max() else {
                throw TranscriptionError.emptyScore
            }
            guard measures.lowerBound <= highest, measures.upperBound >= lowest else {
                throw TranscriptionError.measureRangeOutOfBounds(
                    requested: measures, available: lowest...highest)
            }
            subset.parts = subset.parts.map { part in
                var trimmed = part
                trimmed.measures = part.measures.filter { measure in
                    // A measure whose number is not a plain integer — MusicXML
                    // allows "12a" — is kept rather than silently dropped.
                    guard let number = Int(measure.number) else { return true }
                    return measures.contains(number)
                }
                return trimmed
            }
        }

        return subset.transcript(options: options)
    }

    private func part(for selector: PartSelector) -> Part? {
        switch selector {
        case .index(let position):
            guard position >= 1, position <= parts.count else { return nil }
            return parts[position - 1]
        case .named(let name):
            return parts.first { $0.name == name } ?? parts.first { $0.id == name }
        }
    }

    private static func describe(_ selector: PartSelector) -> String {
        switch selector {
        case .index(let position): return "\(position)"
        case .named(let name): return name
        }
    }
}

/// Transcribes MusicXML to plain text in one call.
///
/// Exactly equivalent to `try Score(musicXML:).transcript(options:).plainText`.
/// See `SPEC.md` §5.
public func transcribe(musicXML data: Data,
                       options: TranscriptOptions = TranscriptOptions()) throws -> String {
    try Score(musicXML: data).transcript(options: options).plainText
}
