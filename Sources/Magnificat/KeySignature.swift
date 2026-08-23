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
