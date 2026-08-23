/// Musical incoherence found while rendering.
///
/// These are the checks that replace schema validation, which `SPEC.md` §6.15
/// measured and set aside: of seven corrupted files, the schema passed five,
/// including a measure short by a beat and a duration contradicting its type.
/// These catch what a reader would actually be misled by.
///
/// Anomalies are **never fatal**. Real OMR output is routinely incoherent, and a
/// reader whose scanned page produced a ragged bar still wants the transcript —
/// with a warning, not a refusal.
public struct Anomaly: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// A measure's durations do not add up to its time signature.
        case measureDurationMismatch
        /// A note sits on a staff the part does not declare.
        case staffOutOfRange
        /// `<duration>` cannot be reconciled with `<type>` and `<divisions>`.
        case durationContradictsType
        /// A `<backup>` would have moved before the start of the measure.
        case backupBeforeMeasureStart
        /// A stream has no such measure, under `.byMeasure` layout.
        case missingMeasureInPart
    }

    public var kind: Kind
    /// The part this was found in.
    public var partID: String
    /// The measure this was found in.
    public var measureNumber: String
    /// Plain English, safe to show a user.
    public var detail: String
}
