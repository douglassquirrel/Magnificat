import Foundation
import Testing
@testable import Magnificat

// SPEC.md §7.7 — every fixture has a checked-in expected transcript, compared
// byte for byte. The hand-written examples in §7 pin down the rules; these are
// the net that catches a change to one rule wrecking thirty other files.
//
// A golden is a reviewed artefact, not a recording of what the code did. There
// is deliberately no regenerate-all flag here: regeneration in bulk turns every
// golden into a restatement of current behaviour, which asserts nothing.

enum Golden {
    static func text(_ relativePath: String) throws -> String {
        let base = try #require(Bundle.module.url(forResource: "Golden", withExtension: nil))
        return try String(contentsOf: base.appendingPathComponent(relativePath),
                          encoding: .utf8)
    }

    /// The first differing line, as a unified-diff fragment. A golden diff that
    /// runs to hundreds of lines is useless for diagnosis.
    static func diff(expected: String, actual: String, context: Int = 2) -> String {
        let want = expected.components(separatedBy: "\n")
        let got = actual.components(separatedBy: "\n")
        guard let first = (0..<max(want.count, got.count)).first(where: {
            want.indices.contains($0) ? (!got.indices.contains($0) || want[$0] != got[$0]) : true
        }) else { return "identical" }

        var report = ["first difference at line \(first + 1):"]
        for line in max(0, first - context)...min(max(want.count, got.count) - 1,
                                                  first + context) {
            if want.indices.contains(line), got.indices.contains(line),
               want[line] == got[line] {
                report.append("  \(want[line])")
            } else {
                if want.indices.contains(line) { report.append("- \(want[line])") }
                if got.indices.contains(line) { report.append("+ \(got[line])") }
            }
        }
        return report.joined(separator: "\n")
    }
}

@Test func everyFixtureStillProducesItsGoldenTranscript() throws {
    for directory in Fixture.directories {
        let base = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
            .appendingPathComponent(directory)
        let names = try FileManager.default.contentsOfDirectory(atPath: base.path)
            .filter { $0.hasSuffix(".musicxml") }.sorted()

        for name in names {
            let data = try Data(contentsOf: base.appendingPathComponent(name))
            let actual = try Score(musicXML: data).transcript().plainText
            let stem = String(name.dropLast(".musicxml".count))
            let expected = try Golden.text("\(directory)/\(stem).txt")
            #expect(actual == expected,
                    Comment(rawValue: "\(directory)/\(stem)\n"
                            + Golden.diff(expected: expected, actual: actual)))
        }
    }
}

@Test func everyOptionHasAGoldenForEveryKindOfInput() throws {
    // SPEC §7.7: no option may go untested, and each must appear on both
    // hand-made and machine-generated input.
    let variants: [(String, String, TranscriptOptions)] = [
        ("by-measure", "openscore", TranscriptOptions(layout: .byMeasure)),
        ("per-event", "openscore", TranscriptOptions(density: .perEvent)),
        ("as-printed", "openscore", TranscriptOptions(accidentalStyle: .asPrinted)),
    ]
    let handMade = ["mayer-1-du-bist-wie-eine-blume", "parry-2-good-night",
                    "webern-5-ihr-tratet-zu-dem-herde", "davies-1-the-apology"]
    let machine = ["piano-beyer-op101-diatonic.windowed",
                   "organ-noordt-modern-engraving.zeus"]

    for (suffix, _, options) in variants {
        for stem in handMade {
            try checkVariant(stem: stem, set: "openscore", suffix: suffix, options: options)
        }
        for stem in machine {
            try checkVariant(stem: stem, set: "omr-output", suffix: suffix, options: options)
        }
    }
}

func checkVariant(stem: String, set: String, suffix: String,
                  options: TranscriptOptions) throws {
    let base = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
    let data = try Data(contentsOf: base.appendingPathComponent("\(set)/\(stem).musicxml"))
    let actual = try Score(musicXML: data).transcript(options: options).plainText
    let expected = try Golden.text("variants/\(stem).\(suffix).txt")
    #expect(actual == expected,
            Comment(rawValue: "\(stem) [\(suffix)]\n"
                    + Golden.diff(expected: expected, actual: actual)))
}

@Test func theDiffHelperPointsAtTheFirstRealDifference() {
    let report = Golden.diff(expected: "a\nb\nc", actual: "a\nX\nc")
    #expect(report.contains("line 2"))
    #expect(report.contains("- b"))
    #expect(report.contains("+ X"))
    #expect(Golden.diff(expected: "a\nb", actual: "a\nb") == "identical")
}
