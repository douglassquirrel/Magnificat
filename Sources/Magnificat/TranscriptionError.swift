/// Everything that can stop Magnificat reading a file.
///
/// Musical incoherence is *not* here: a measure that does not add up is reported
/// as an anomaly and the transcript is still produced. See `SPEC.md` §6.15.
public enum TranscriptionError: Error, Equatable {
    /// The document is not well-formed XML.
    case malformedXML(line: Int, message: String)
    /// The root element is not `score-partwise`.
    case unsupportedRootElement(found: String)
    /// A `.mxl` file is a ZIP archive that could not be read — not a valid ZIP
    /// structure, no `META-INF/container.xml`, its root entry missing, or an
    /// unsupported compression method. Distinct from `.malformedXML`, which
    /// means the *extracted* MusicXML itself does not parse.
    case corruptedArchive(String)
    /// The file parsed but holds no music.
    case emptyScore
    /// An element carried a value that cannot mean anything.
    case invalidValue(element: String, value: String)
    /// A part was asked for that the score does not have.
    case unknownPart(String)
    /// A measure range was asked for that lies outside the score.
    case measureRangeOutOfBounds(requested: ClosedRange<Int>, available: ClosedRange<Int>)
}
