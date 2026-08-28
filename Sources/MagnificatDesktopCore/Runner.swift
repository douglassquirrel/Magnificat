import Foundation
import Magnificat

/// Runs one pass: scan `folder/in`, transcribe every `.musicxml` file with
/// default options, write `folder/out/<stem>.txt` and `folder/out/last-run.log`.
/// See `DESKTOP-SPEC.md` §6.
public struct Runner: Sendable {
    public init() {}

    /// - Parameters:
    ///   - folder: FOLDER, containing (or to be given) `in/` and `out/`.
    ///   - now: injected so tests never depend on the wall clock.
    public func run(folder: URL, now: Date = Date()) -> RunResult {
        let inFolder = folder.appendingPathComponent("in")
        let outFolder = folder.appendingPathComponent("out")

        do {
            try ConfigurationStore.ensureFolders(for: DesktopConfiguration(folder: folder))
        } catch {
            // The folders could not even be created — there is nowhere to write
            // a log either, so the RunResult itself is the only channel here.
            // DESKTOP-SPEC.md §6.
            return RunResult(status: .failed, results: [],
                             topLevelFailureReason: String(describing: error),
                             timestamp: now, folder: folder)
        }

        // Not covered by a test: ensureFolders just succeeded, so this only
        // fires if inFolder is removed in the instant between that call and
        // this one — a genuine race, not deterministically provocable without
        // either a flaky timing-dependent test or a test-only hook added to
        // production code purely to force it. Left in as real defense.
        let scanned: [ScannedFile]
        do {
            scanned = try scanInputFolder(inFolder)
        } catch {
            return RunResult(status: .failed, results: [],
                             topLevelFailureReason: "could not read FOLDER/in: \(error.localizedDescription)",
                             timestamp: now, folder: folder)
        }

        let results = scanned.map { file in process(file, outFolder: outFolder) }
        let status = RunStatus.compute(from: results, topLevelFailureReason: nil)
        let result = RunResult(status: status, results: results,
                               timestamp: now, folder: folder)

        try? result.logText.write(to: outFolder.appendingPathComponent("last-run.log"),
                                  atomically: true, encoding: .utf8)
        return result
    }

    private func process(_ file: ScannedFile, outFolder: URL) -> FileResult {
        guard file.isMusicXML else {
            return FileResult(inputName: file.name, outcome: .skipped(reason: "not .musicxml"))
        }

        let outputName = Self.outputName(for: file.name)
        do {
            let data = try Data(contentsOf: file.url)
            let score = try Score(musicXML: data)
            let transcript = score.transcript()
            try transcript.plainText.write(to: outFolder.appendingPathComponent(outputName),
                                           atomically: true, encoding: .utf8)
            return FileResult(inputName: file.name,
                              outcome: .succeeded(outputName: outputName,
                                                 anomalies: transcript.anomalies))
        } catch let error as TranscriptionError {
            return FileResult(inputName: file.name, outcome: .failed(reason: Self.describe(error)))
        } catch {
            return FileResult(inputName: file.name,
                              outcome: .failed(reason: error.localizedDescription))
        }
    }

    /// `song.musicxml` → `song.txt`, matching case-insensitively so
    /// `Song.MUSICXML` still becomes `Song.txt` rather than keeping its
    /// original extension untouched.
    static func outputName(for inputName: String) -> String {
        guard inputName.count > ".musicxml".count,
              inputName.lowercased().hasSuffix(".musicxml") else {
            return inputName + ".txt"
        }
        return String(inputName.dropLast(".musicxml".count)) + ".txt"
    }

    /// Wording for this app's log and window — kept separate from
    /// `MagnificatCLI`'s own `describe(_:)`, which references CLI flags
    /// (`--parts`) that do not exist here. `.unknownPart` and
    /// `.measureRangeOutOfBounds` can never actually occur: this app never
    /// subsets by part or measure range (`DESKTOP-SPEC.md` §9). They are
    /// still handled, so the switch stays exhaustive against a future case.
    static func describe(_ error: TranscriptionError) -> String {
        switch error {
        case .malformedXML(let line, let message):
            return "not well-formed XML: line \(line), \(message)"
        case .unsupportedRootElement(let found):
            return "not a partwise MusicXML score (found <\(found)>)"
        case .corruptedArchive(let why):
            return "could not read the .mxl archive: \(why)"
        case .emptyScore:
            return "empty score — the file holds no music"
        case .invalidValue(let element, let value):
            return "<\(element)> carries the value \(value), which cannot mean anything"
        case .unknownPart(let name):
            return "no such part: \(name)"
        case .measureRangeOutOfBounds(let requested, let available):
            return "measures \(requested.lowerBound)-\(requested.upperBound) are outside "
                 + "the score's \(available.lowerBound)-\(available.upperBound)"
        }
    }
}
