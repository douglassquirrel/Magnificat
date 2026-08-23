import Foundation
import Testing
@testable import MagnificatCLI
@testable import Magnificat

// CLAUDE.md holds the CLI to the same standard as the library: its argument
// parsing and exit codes get tests written first. SPEC.md §12 fixes the surface.

@Test func parsesAFilePathOnItsOwn() throws {
    let invocation = try Invocation(arguments: ["song.musicxml"])
    #expect(invocation.path == "song.musicxml")
    #expect(invocation.mode == .transcribe)
    #expect(invocation.options == TranscriptOptions())
}

@Test func parsesEveryRenderingOption() throws {
    let invocation = try Invocation(arguments: [
        "song.musicxml", "--layout", "by-measure",
        "--density", "per-event", "--accidentals", "as-printed",
    ])
    #expect(invocation.options == TranscriptOptions(layout: .byMeasure,
                                                   density: .perEvent,
                                                   accidentalStyle: .asPrinted))
}

@Test func parsesRepeatedPartSelectorsByPositionAndName() throws {
    let invocation = try Invocation(arguments: [
        "song.musicxml", "--part", "1", "--part", "Pianoforte",
    ])
    #expect(invocation.parts == [.index(1), .named("Pianoforte")])
}

@Test func parsesAMeasureRange() throws {
    #expect(try Invocation(arguments: ["s.musicxml", "--measures", "4-12"]).measures == 4...12)
    // A single measure is a range of one.
    #expect(try Invocation(arguments: ["s.musicxml", "--measures", "7"]).measures == 7...7)
}

@Test func recognisesTheModesThatDoNotTranscribe() throws {
    #expect(try Invocation(arguments: ["--help"]).mode == .help)
    #expect(try Invocation(arguments: ["s.musicxml", "--info"]).mode == .info)
    #expect(try Invocation(arguments: ["s.musicxml", "--parts"]).mode == .listParts)
    // No arguments at all is a request for help, not an error.
    #expect(try Invocation(arguments: []).mode == .help)
}

@Test func rejectsUnknownOptionsRatherThanIgnoringThem() {
    #expect(throws: UsageError.unknownOption("--loud")) {
        _ = try Invocation(arguments: ["s.musicxml", "--loud"])
    }
}

@Test func rejectsAnOptionWithNoValue() {
    #expect(throws: UsageError.missingValue("--layout")) {
        _ = try Invocation(arguments: ["s.musicxml", "--layout"])
    }
}

@Test func rejectsAValueTheOptionDoesNotAccept() {
    #expect(throws: UsageError.badValue(option: "--density", value: "per-hour")) {
        _ = try Invocation(arguments: ["s.musicxml", "--density", "per-hour"])
    }
}

@Test func rejectsAMeasureRangeThatIsNotOne() {
    #expect(throws: UsageError.badValue(option: "--measures", value: "12-4")) {
        _ = try Invocation(arguments: ["s.musicxml", "--measures", "12-4"])
    }
    #expect(throws: UsageError.badValue(option: "--measures", value: "four")) {
        _ = try Invocation(arguments: ["s.musicxml", "--measures", "four"])
    }
}

@Test func rejectsAsecondFilePath() {
    #expect(throws: UsageError.tooManyPaths) {
        _ = try Invocation(arguments: ["one.musicxml", "two.musicxml"])
    }
}

@Test func requiresAPathForEveryModeThatReadsAFile() {
    #expect(throws: UsageError.noPath) { _ = try Invocation(arguments: ["--info"]) }
}

// Exit codes. SPEC §12 asks for distinct codes for "could not read the file" and
// "could not transcribe it", so a script can tell them apart.

@Test func exitsZeroOnSuccess() throws {
    let url = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        .appendingPathComponent("openscore/mayer-1-du-bist-wie-eine-blume.musicxml")
    var output = CapturingOutput()
    let code = MagnificatCLI.run(arguments: [url.path], output: &output)
    #expect(code == 0)
    #expect(output.standardOutput.contains("Du bist wie eine Blume"))
    #expect(output.standardError.isEmpty)
}

@Test func exitsWithAUsageCodeAndWritesToStandardError() {
    var output = CapturingOutput()
    let code = MagnificatCLI.run(arguments: ["--loud"], output: &output)
    #expect(code == 2)
    #expect(output.standardOutput.isEmpty)
    #expect(output.standardError.contains("--loud"))
}

@Test func exitsWithAReadCodeWhenTheFileIsMissing() {
    var output = CapturingOutput()
    let code = MagnificatCLI.run(arguments: ["/no/such/file.musicxml"], output: &output)
    #expect(code == 3)
    #expect(output.standardError.contains("/no/such/file.musicxml"))
}

@Test func exitsWithATranscribeCodeWhenTheFileIsNotMusicXML() throws {
    let path = FileManager.default.temporaryDirectory
        .appendingPathComponent("magnificat-test-\(UUID().uuidString).musicxml")
    try Data("<html><body>not music</body></html>".utf8).write(to: path)
    defer { try? FileManager.default.removeItem(at: path) }

    var output = CapturingOutput()
    let code = MagnificatCLI.run(arguments: [path.path], output: &output)
    #expect(code == 4)
    #expect(output.standardError.lowercased().contains("score-partwise")
            || output.standardError.contains("html"))
}

@Test func helpNamesEveryOption() {
    var output = CapturingOutput()
    let code = MagnificatCLI.run(arguments: ["--help"], output: &output)
    #expect(code == 0)
    for option in ["--info", "--part", "--parts", "--measures", "--layout",
                   "--density", "--accidentals", "--help"] {
        #expect(output.standardOutput.contains(option), "help should name \(option)")
    }
}

@Test func listsPartsWithTheirPositions() throws {
    let url = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        .appendingPathComponent("openscore/mayer-1-du-bist-wie-eine-blume.musicxml")
    var output = CapturingOutput()
    let code = MagnificatCLI.run(arguments: [url.path, "--parts"], output: &output)
    #expect(code == 0)
    #expect(output.standardOutput.contains("1. Singstimme, Voice"))
    #expect(output.standardOutput.contains("2. Pianoforte"))
}

@Test func reportsAnomaliesOnStandardErrorSoTheyDoNotPolluteTheTranscript() throws {
    // Anomalies are a warning about the file, not part of the reading. Sending
    // them to stdout would put them in a braille export.
    let url = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        .appendingPathComponent("omr-output/organ-noordt-modern-engraving.zeus.musicxml")
    var output = CapturingOutput()
    let code = MagnificatCLI.run(arguments: [url.path], output: &output)
    #expect(code == 0)
    #expect(!output.standardOutput.contains("Warning:"))
}

/// Collects what the CLI writes, so exit codes and streams can be tested without
/// a subprocess.
struct CapturingOutput: TextOutput {
    var standardOutput = ""
    var standardError = ""
    mutating func write(_ text: String) { standardOutput += text }
    mutating func writeError(_ text: String) { standardError += text }
}
