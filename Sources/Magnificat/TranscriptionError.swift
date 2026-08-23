/// Everything that can stop Magnificat reading a file.
///
/// Musical incoherence is *not* here: a measure that does not add up is reported
/// as an anomaly and the transcript is still produced. See `SPEC.md` §6.15.
public enum TranscriptionError: Error, Equatable {
    /// The document is not well-formed XML.
    case malformedXML(line: Int, message: String)
    /// The root element is not `score-partwise`.
    case unsupportedRootElement(found: String)
    /// A format this library deliberately does not read, such as compressed `.mxl`.
    case unsupportedFormat(String)
    /// The file parsed but holds no music.
    case emptyScore
    /// An element carried a value that cannot mean anything.
    case invalidValue(element: String, value: String)
}
