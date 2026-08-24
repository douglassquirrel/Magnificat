/// A key signature, expressed the way MusicXML does: a count of sharps or flats
/// on the circle of fifths.
public struct KeySignature: Sendable, Equatable {
    /// Positive for sharps, negative for flats, zero for none. Range -7 to 7.
    public var fifths: Int
    /// The mode, when the file states one. Absent in most real files.
    public var mode: String?

    public init(fifths: Int, mode: String? = nil) {
        self.fifths = fifths
        self.mode = mode
    }

    /// The tonic names for -7 to 7 fifths, major then minor.
    private static let majorTonics = ["C flat", "G flat", "D flat", "A flat", "E flat",
                                      "B flat", "F", "C", "G", "D", "A", "E", "B",
                                      "F sharp", "C sharp"]
    private static let minorTonics = ["A flat", "E flat", "B flat", "F", "C", "G", "D",
                                      "A", "E", "B", "F sharp", "C sharp", "G sharp",
                                      "D sharp", "A sharp"]

    /// True when the file says outright that the music has no key — MusicXML's
    /// `<mode>none</mode>`, which the Webern uses.
    var statesNoKey: Bool { mode?.lowercased() == "none" }

    /// The key spoken as plain text.
    ///
    /// **The key is named only when the file names it.** MusicXML states `<mode>`
    /// on 3 of the 92 `<key>` elements in the fixtures, so for almost every real
    /// score there is no name to give — and inferring one from the accidental
    /// count is a guess. It reads as fact to somebody who cannot check it, and it
    /// is often wrong: the Brahms carries one sharp and is in E minor, and the old
    /// rule called it G major.
    ///
    /// What is always given instead is **which notes the signature alters**. That
    /// is a fact, it asserts no tonic, and it tells a player more than a name
    /// does. See `SPEC.md` §6.13.
    var spokenName: String {
        let accidentals = spokenAccidentals
        guard let mode, !mode.isEmpty, !statesNoKey else { return accidentals }

        switch mode.lowercased() {
        case "major", "minor":
            let index = fifths + 7
            guard Self.majorTonics.indices.contains(index) else { return accidentals }
            let isMinor = mode.lowercased() == "minor"
            let tonic = isMinor ? Self.minorTonics[index] : Self.majorTonics[index]
            return "\(tonic) \(isMinor ? "minor" : "major"), \(accidentals)"
        default:
            // Working out the tonic of dorian or mixolydian from the accidental
            // count needs a table per mode. The file said the mode; that is what
            // is said back, without inventing a tonic to go with it.
            return "\(mode), \(accidentals)"
        }
    }

    /// The count of sharps or flats, and which notes they fall on.
    private var spokenAccidentals: String {
        guard fifths != 0 else { return "no sharps or flats" }
        let altered = Self.alteredSteps(fifths: fifths)
        let count = abs(fifths) == 1
            ? (fifths > 0 ? "1 sharp" : "1 flat")
            : "\(abs(fifths)) \(fifths > 0 ? "sharps" : "flats")"
        guard !altered.isEmpty else { return count }
        return ([count] + altered).joined(separator: ", ")
    }

    /// The notes this signature alters, in the order they are written on the staff.
    static func alteredSteps(fifths: Int) -> [String] {
        guard fifths != 0 else { return [] }
        let word = fifths > 0 ? "sharp" : "flat"
        let order = fifths > 0 ? sharpOrder : sharpOrder.reversed()
        return order.prefix(min(abs(fifths), 7)).map { "\($0.rawValue) \(word)" }
    }

    /// Sharps appear in this order; flats in the reverse of it.
    static let sharpOrder: [Step] = [.f, .c, .g, .d, .a, .e, .b]

    /// The alteration this key signature applies to `step`, in semitones.
    ///
    /// Returns 0 when the key leaves the step alone, which is what makes a
    /// printed natural on that step meaningful. See `SPEC.md` §6.2.
    func alteration(of step: Step) -> Int {
        guard let position = Self.sharpOrder.firstIndex(of: step) else { return 0 }
        if fifths > 0 { return position < fifths ? 1 : 0 }
        if fifths < 0 {
            // Flats run backwards through the same order: B, E, A, D, G, C, F.
            let flatPosition = Self.sharpOrder.count - 1 - position
            return flatPosition < -fifths ? -1 : 0
        }
        return 0
    }
}
