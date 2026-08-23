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

    /// The key spoken as plain text: tonic, mode, and the count of accidentals.
    ///
    /// Where the file states no `<mode>` the major name is given, which is what
    /// the accidentals themselves say; asserting a mode the file did not state
    /// would be inventing information. See `SPEC.md` §6.13.
    var spokenName: String {
        let index = fifths + 7
        guard Self.majorTonics.indices.contains(index) else {
            return "\(fifths) on the circle of fifths"
        }
        let isMinor = mode?.lowercased() == "minor"
        let tonic = isMinor ? Self.minorTonics[index] : Self.majorTonics[index]
        let quality = isMinor ? "minor" : "major"

        let count: String
        switch fifths {
        case 0: count = "no sharps or flats"
        case 1: count = "1 sharp"
        case -1: count = "1 flat"
        case let n where n > 0: count = "\(n) sharps"
        default: count = "\(-fifths) flats"
        }
        return "\(tonic) \(quality), \(count)"
    }

    /// Sharps appear in this order; flats in the reverse of it.
    private static let sharpOrder: [Step] = [.f, .c, .g, .d, .a, .e, .b]

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
