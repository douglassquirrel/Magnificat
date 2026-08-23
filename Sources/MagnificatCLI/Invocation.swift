import Foundation
import Magnificat

/// Something wrong with the command line itself, as opposed to the file.
public enum UsageError: Error, Equatable {
    case unknownOption(String)
    case missingValue(String)
    case badValue(option: String, value: String)
    case tooManyPaths
    case noPath
}

/// What one run of the CLI was asked to do.
///
/// Parsing is separated from doing so it can be tested on its own, which
/// `CLAUDE.md` requires of the CLI as much as of the library.
public struct Invocation: Equatable {
    public enum Mode: Equatable { case transcribe, info, listParts, help }

    public var path: String?
    public var mode: Mode = .transcribe
    public var options = TranscriptOptions()
    public var parts: [PartSelector] = []
    public var measures: ClosedRange<Int>?

    /// Parses the arguments, which must not include the program name.
    public init(arguments: [String]) throws {
        // No arguments at all is a request for help, not a mistake to scold over.
        guard !arguments.isEmpty else {
            mode = .help
            return
        }

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            index += 1

            /// The value following an option, or a `missingValue` failure.
            func value() throws -> String {
                guard index < arguments.count else {
                    throw UsageError.missingValue(argument)
                }
                defer { index += 1 }
                return arguments[index]
            }

            switch argument {
            case "--help", "-h":
                mode = .help
            case "--info":
                mode = .info
            case "--parts":
                mode = .listParts

            case "--part":
                let text = try value()
                // A bare number is a position; anything else is a name. Positions
                // matter because OMR output leaves parts unnamed.
                if let position = Int(text) {
                    parts.append(.index(position))
                } else {
                    parts.append(.named(text))
                }

            case "--measures":
                let text = try value()
                guard let range = Self.measureRange(text) else {
                    throw UsageError.badValue(option: "--measures", value: text)
                }
                measures = range

            case "--layout":
                let text = try value()
                switch text {
                case "by-part": options.layout = .byPart
                case "by-measure": options.layout = .byMeasure
                default: throw UsageError.badValue(option: "--layout", value: text)
                }

            case "--density":
                let text = try value()
                switch text {
                case "per-measure": options.density = .perMeasure
                case "per-event": options.density = .perEvent
                default: throw UsageError.badValue(option: "--density", value: text)
                }

            case "--accidentals":
                let text = try value()
                switch text {
                case "sounding": options.accidentalStyle = .sounding
                case "as-printed": options.accidentalStyle = .asPrinted
                default: throw UsageError.badValue(option: "--accidentals", value: text)
                }

            default:
                guard !argument.hasPrefix("-") else {
                    throw UsageError.unknownOption(argument)
                }
                guard path == nil else { throw UsageError.tooManyPaths }
                path = argument
            }
        }

        if mode != .help && path == nil { throw UsageError.noPath }
    }

    /// `4-12` or `7`. Reversed and non-numeric ranges are refused rather than
    /// quietly reinterpreted.
    static func measureRange(_ text: String) -> ClosedRange<Int>? {
        let parts = text.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 1, let only = Int(parts[0]) { return only...only }
        guard parts.count == 2, let low = Int(parts[0]), let high = Int(parts[1]),
              low <= high else { return nil }
        return low...high
    }
}
