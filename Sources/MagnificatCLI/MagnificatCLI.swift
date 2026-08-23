import Foundation
import Magnificat

/// The demo client. Thin by design: it parses arguments, calls the library, and
/// prints. All the real logic lives in `Magnificat`. See `SPEC.md` §12.
public enum MagnificatCLI {
    /// Exit codes. A script needs to tell "could not read the file" apart from
    /// "could not transcribe it", so they are distinct.
    public enum ExitCode {
        public static let success: Int32 = 0
        public static let usage: Int32 = 2
        public static let couldNotRead: Int32 = 3
        public static let couldNotTranscribe: Int32 = 4
    }

    public static let helpText = """
    magnificat — turn MusicXML into plain text for a screen reader or braille display

    Usage: magnificat <file.musicxml> [options]

      --info                    print the score heading only and exit
      --part <n-or-name>        restrict to one part, by 1-based position or by
                                name (repeatable; position works on unnamed parts)
      --parts                   list the parts with their positions and names
      --measures <a>-<b>        restrict to a measure range, or <a> for one measure
      --layout by-part|by-measure          (default: by-part)
      --density per-measure|per-event      (default: per-measure)
      --accidentals sounding|as-printed    (default: sounding)
      --help                    print this and exit

    The transcript goes to standard output; warnings and errors go to standard
    error, so the transcript can be redirected to a file on its own.

    Exit codes: 0 success, 2 bad usage, 3 could not read the file,
    4 could not transcribe it.
    """

    /// Runs one invocation and returns its exit code.
    public static func run<Output: TextOutput>(arguments: [String],
                                                 output: inout Output) -> Int32 {
        let invocation: Invocation
        do {
            invocation = try Invocation(arguments: arguments)
        } catch let error as UsageError {
            output.writeError(describe(error) + "\n")
            output.writeError("Try --help.\n")
            return ExitCode.usage
        } catch {
            output.writeError("\(error)\n")
            return ExitCode.usage
        }

        if invocation.mode == .help {
            output.write(helpText + "\n")
            return ExitCode.success
        }

        guard let path = invocation.path else {
            output.writeError("No file given. Try --help.\n")
            return ExitCode.usage
        }

        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            output.writeError("Could not read \(path): "
                              + "\(error.localizedDescription)\n")
            return ExitCode.couldNotRead
        }

        do {
            let score = try Score(musicXML: data)
            switch invocation.mode {
            case .listParts:
                for (position, name) in score.summary.partNames.enumerated() {
                    output.write("\(position + 1). \(name)\n")
                }
            case .info:
                let transcript = score.transcript()
                for line in transcript.lines where line.kind == .scoreHeading {
                    output.write(line.text + "\n")
                }
            default:
                let transcript = try score.transcript(
                    options: invocation.options,
                    parts: invocation.parts.isEmpty ? nil : invocation.parts,
                    measures: invocation.measures)
                output.write(transcript.plainText)
                // Anomalies are a warning about the file, not part of the
                // reading: on stdout they would end up in a braille export.
                for anomaly in transcript.anomalies {
                    output.writeError("Warning: part \(anomaly.partID), measure "
                                      + "\(anomaly.measureNumber): \(anomaly.detail)\n")
                }
            }
            return ExitCode.success
        } catch let error as TranscriptionError {
            output.writeError(describe(error) + "\n")
            return ExitCode.couldNotTranscribe
        } catch {
            output.writeError("\(error)\n")
            return ExitCode.couldNotTranscribe
        }
    }

    static func describe(_ error: UsageError) -> String {
        switch error {
        case .unknownOption(let option): return "Unknown option \(option)."
        case .missingValue(let option): return "\(option) needs a value."
        case .badValue(let option, let value): return "\(option) does not accept \(value)."
        case .tooManyPaths: return "Only one file can be given."
        case .noPath: return "No file given."
        }
    }

    static func describe(_ error: TranscriptionError) -> String {
        switch error {
        case .malformedXML(let line, let message):
            return "This file is not well-formed XML: line \(line), \(message)"
        case .unsupportedRootElement(let found):
            return "This is not a partwise MusicXML score: the document is <\(found)>, "
                 + "not <score-partwise>."
        case .unsupportedFormat(let what):
            return "Magnificat does not read \(what). Uncompress it first."
        case .emptyScore:
            return "This file holds no music."
        case .invalidValue(let element, let value):
            return "<\(element)> carries the value \(value), which cannot mean anything."
        case .unknownPart(let name):
            return "There is no part \(name) in this score. Try --parts."
        case .measureRangeOutOfBounds(let requested, let available):
            return "Measures \(requested.lowerBound) to \(requested.upperBound) are outside "
                 + "this score, which has \(available.lowerBound) to \(available.upperBound)."
        }
    }
}
