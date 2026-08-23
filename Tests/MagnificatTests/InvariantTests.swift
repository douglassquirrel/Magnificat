import Foundation
import Testing
@testable import Magnificat

// SPEC.md §7.8 — one property test over every line of every golden, asserting the
// §6.1 rules that no individual example can guarantee. This is the test that
// catches a flat sign leaking into the output through a code path nobody thought
// about, which is the single most likely way this library fails its users.
//
// It has already earned its place: the Webern carries a SMuFL glyph inside
// <words> and the Satie carries two inside a <lyric>, both of which reached the
// transcript while every other test passed.

/// Characters that must never appear. Written as an explicit deny-list so a new
/// one cannot creep in through a new rule.
let forbiddenScalars: [(name: String, range: ClosedRange<UInt32>)] = [
    ("musical symbols", 0x1D100...0x1D1FF),
    ("miscellaneous symbols", 0x2600...0x27BF),
    ("emoticons", 0x1F600...0x1F64F),
    ("pictographs", 0x1F300...0x1F5FF),
    ("transport symbols", 0x1F680...0x1F6FF),
    ("supplemental symbols", 0x1F900...0x1F9FF),
    ("box drawing", 0x2500...0x257F),
    ("block elements", 0x2580...0x259F),
    ("arrows", 0x2190...0x21FF),
    ("private use", 0xE000...0xF8FF),
    ("private use plane 15", 0xF0000...0xFFFFD),
    ("private use plane 16", 0x100000...0x10FFFD),
]

/// Characters that must never appear anywhere, in any line. A music glyph or a
/// zero-width space is not text: it means nothing to a screen reader and nothing
/// on a braille display, wherever it came from.
let forbiddenCharacters: [(name: String, scalar: Unicode.Scalar)] = [
    ("flat sign", "\u{266D}"), ("natural sign", "\u{266E}"), ("sharp sign", "\u{266F}"),
    ("eighth note", "\u{266A}"), ("beamed notes", "\u{266B}"), ("quarter note", "\u{2669}"),
    ("non-breaking space", "\u{00A0}"), ("zero-width space", "\u{200B}"),
]

/// Typographic punctuation, forbidden in the words Magnificat writes but allowed
/// through in the words the file supplied.
///
/// The distinction was forced by the fixtures: Bridge's lyrics spell "daffodils"
/// with a typographic apostrophe, and Beethoven's and Davies's do the same.
/// SPEC §6.1 requires lyric text to pass through unchanged, and an apostrophe is
/// ordinary English punctuation that both a screen reader and a braille display
/// handle. Rewriting it would be editing what the file says.
let forbiddenInGeneratedText: [(name: String, scalar: Unicode.Scalar)] = [
    ("left smart quote", "\u{201C}"), ("right smart quote", "\u{201D}"),
    ("left single quote", "\u{2018}"), ("right single quote", "\u{2019}"),
    ("em dash", "\u{2014}"), ("en dash", "\u{2013}"), ("ellipsis", "\u{2026}"),
]

/// True when a line carries text the file supplied — a lyric, a title, a
/// composer's name, a tempo marking — rather than words Magnificat wrote.
func carriesFileText(_ line: TranscriptLine) -> Bool {
    line.kind == .scoreHeading || line.kind == .lyricsSummary
        || line.text.contains("lyric ") || line.text.contains("Lyric: ")
        || line.text.contains("Verse ")
}

func checkInvariants(of text: String, source: String) {
    #expect(!text.contains("\r"), "\(source): must use \\n, never \\r")
    #expect(text.hasSuffix("\n"), "\(source): must end with a newline")
    #expect(!text.hasSuffix("\n\n"), "\(source): must end with exactly one newline")

    for (number, line) in text.components(separatedBy: "\n").dropLast().enumerated() {
        let where_ = "\(source):\(number + 1)"
        #expect(line == line.trimmingCharacters(in: .whitespaces),
                "\(where_): leading or trailing whitespace in \(line.debugDescription)")
        #expect(!line.contains("\t"), "\(where_): contains a tab")
        #expect(!line.isEmpty, "\(where_): empty line")

        for scalar in line.unicodeScalars {
            #expect(scalar.value >= 0x20,
                    "\(where_): control character U+\(String(scalar.value, radix: 16))")
            for (name, range) in forbiddenScalars where range.contains(scalar.value) {
                Issue.record(Comment(rawValue: "\(where_): \(name) "
                                     + "U+\(String(scalar.value, radix: 16, uppercase: true))"))
            }
            for (name, forbidden) in forbiddenCharacters where scalar == forbidden {
                Issue.record(Comment(rawValue: "\(where_): \(name)"))
            }
        }
    }
}

@Test func everyGoldenObeysThePlainTextRules() throws {
    let base = try #require(Bundle.module.url(forResource: "Golden", withExtension: nil))
    let files = FileManager.default.enumerator(atPath: base.path)?
        .compactMap { $0 as? String }.filter { $0.hasSuffix(".txt") }.sorted() ?? []
    #expect(files.count >= 49, "expected a golden per fixture plus the variants")

    for file in files {
        let text = try String(contentsOf: base.appendingPathComponent(file), encoding: .utf8)
        checkInvariants(of: text, source: file)
    }
}

@Test func everyOptionCombinationObeysThePlainTextRules() throws {
    // Stronger than the goldens alone: every fixture through every combination,
    // so a rule that only fires under one option cannot slip through.
    for layout in [TranscriptLayout.byPart, .byMeasure] {
        for density in [TranscriptDensity.perMeasure, .perEvent] {
            for style in [AccidentalStyle.sounding, .asPrinted] {
                let options = TranscriptOptions(layout: layout, density: density,
                                                accidentalStyle: style)
                for (name, data) in Fixture.all {
                    let text = try Score(musicXML: data).transcript(options: options).plainText
                    checkInvariants(of: text, source: "\(name) \(layout) \(density) \(style)")
                }
            }
        }
    }
}

@Test func typographicPunctuationNeverAppearsInWordsMagnificatWrote() throws {
    // Smart quotes and dashes are allowed through inside a lyric or a title, and
    // nowhere else: SPEC §6.1 forbids them in the musical vocabulary.
    for (name, data) in Fixture.all {
        for line in try Score(musicXML: data).transcript().lines
        where !carriesFileText(line) {
            for scalar in line.text.unicodeScalars {
                for (label, forbidden) in forbiddenInGeneratedText where scalar == forbidden {
                    Issue.record(Comment(rawValue: "\(name): \(label) in "
                                         + line.text.debugDescription))
                }
            }
        }
    }
}

/// Every non-ASCII character the file itself supplies — in lyrics, titles,
/// composer names, and tempo or expression markings.
func nonASCIIFromTheFile(_ score: Score) -> Set<Unicode.Scalar> {
    var supplied: [String] = [
        score.metadata.workTitle, score.metadata.movementTitle,
        score.metadata.composer, score.metadata.lyricist,
    ].compactMap { $0 }
    supplied += score.parts.compactMap(\.name)

    func collect(_ direction: Direction) {
        switch direction {
        case .words(let text): supplied.append(text)
        case .rehearsal(let mark): supplied.append(mark)
        case .dynamic(let mark): supplied.append(mark)
        case .compound(let parts): parts.forEach(collect)
        default: break
        }
    }
    for event in score.parts.flatMap(\.measures).flatMap(\.events) {
        switch event {
        case .note(let note): supplied += note.lyrics.map(\.text)
        case .direction(let placed): collect(placed.direction)
        case .rest: break
        }
    }
    return Set(supplied.flatMap { $0.unicodeScalars }.filter { !$0.isASCII })
}

@Test func nonASCIIAppearsOnlyWhereTheFileSuppliedIt() throws {
    // SPEC §6.1: the musical vocabulary is ASCII throughout, and the file's own
    // words — German lyrics, "Modéré", "Träumerisch" — are the one thing that
    // passes through. Checked structurally rather than by guessing from the line,
    // because at .perMeasure density one line holds both.
    for (name, data) in Fixture.all {
        let score = try Score(musicXML: data)
        let allowed = nonASCIIFromTheFile(score)
        for line in score.transcript().lines {
            for scalar in line.text.unicodeScalars where !scalar.isASCII {
                #expect(allowed.contains(scalar), Comment(rawValue:
                    "\(name): U+\(String(scalar.value, radix: 16, uppercase: true)) "
                    + "is not in anything the file supplied: \(line.text.debugDescription)"))
            }
        }
    }
}

@Test func everyMeasureLineNamesAMeasureThatExists() throws {
    for (name, data) in Fixture.all {
        let score = try Score(musicXML: data)
        let real = Set(score.parts.flatMap(\.measures).map(\.number))
        for line in score.transcript().lines {
            guard let number = line.measureNumber else { continue }
            #expect(real.contains(number), Comment(rawValue:
                "\(name): line names measure \(number), which the file does not have"))
        }
    }
}
