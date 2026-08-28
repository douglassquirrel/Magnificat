import Foundation
import Testing
@testable import Magnificat

// CLAUDE.md: "Show real code that actually works. Run every snippet before
// committing it." These are the README's examples, verbatim, so a snippet that
// stops compiling or stops producing what the README claims fails the suite.

@Test func readmeQuickStart() throws {
    let data = try Fixture.named("mayer-1-du-bist-wie-eine-blume.musicxml")

    // --- README: Quick start ---
    let text = try transcribe(musicXML: data)
    // --- end ---

    #expect(text.hasPrefix("Du bist wie eine Blume\nEmilie Mayer\n"))
}

@Test func readmeSummary() throws {
    let data = try Fixture.named("mayer-1-du-bist-wie-eine-blume.musicxml")

    // --- README: What is this file? ---
    let score = try Score(musicXML: data)
    let summary = score.summary
    // summary.title       -> "Du bist wie eine Blume"
    // summary.composer    -> "Emilie Mayer"
    // summary.partNames   -> ["Singstimme, Voice", "Pianoforte"]
    // summary.measureCount-> 32
    // summary.hasLyrics   -> true
    // --- end ---

    #expect(summary.title == "Du bist wie eine Blume")
    #expect(summary.composer == "Emilie Mayer")
    #expect(summary.partNames == ["Singstimme, Voice", "Pianoforte"])
    #expect(summary.measureCount == 32)
    #expect(summary.hasLyrics)
}

@Test func readmeOneSingersLine() throws {
    let data = try Fixture.named("mayer-1-du-bist-wie-eine-blume.musicxml")

    // --- README: Just my line, bars 4 to 6 ---
    let score = try Score(musicXML: data)
    let transcript = try score.transcript(parts: [.index(1)], measures: 4...6)
    let lines = transcript.lines.filter { $0.kind == .measure }.map(\.text)
    // --- end ---

    #expect(lines.first ==
        "Measure 4. Half rest. Quarter rest. Dynamic: piano. E flat 4, quarter, lyric Du.")
}

@Test func readmeBrailleFriendlyOptions() throws {
    let data = try Fixture.named("mayer-1-du-bist-wie-eine-blume.musicxml")

    // --- README: One line per note, for a braille display ---
    let options = TranscriptOptions(density: .perEvent)
    let text = try Score(musicXML: data).transcript(options: options).plainText
    // --- end ---

    #expect(text.contains("Measure 5\nA flat 4, dotted quarter\nLyric: bist\n"))
}

@Test func readmeAnomalies() throws {
    let data = try Fixture.named("organ-noordt-modern-engraving.zeus.musicxml")

    // --- README: Warning a reader about a scruffy file ---
    let transcript = try Score(musicXML: data).transcript()
    for anomaly in transcript.anomalies {
        _ = "Measure \(anomaly.measureNumber): \(anomaly.detail)"
    }
    // --- end ---

    #expect(!transcript.anomalies.isEmpty)
    #expect(!transcript.lines.isEmpty, "the transcript is produced anyway")
}

@Test func readmeAnomalySummaryInTheDeliveredText() throws {
    let data = try Fixture.named("organ-noordt-modern-engraving.zeus.musicxml")

    // --- README: Anomalies embedded in the delivered text ---
    let transcript = try Score(musicXML: data).transcript()
    let text = transcript.plainTextWithAnomalySummary
    // --- end ---

    let summary = try #require(transcript.anomalySummary)
    #expect(text.hasPrefix(summary + "\n\n"))
    #expect(text.hasSuffix(transcript.plainText))
}

@Test func readmeErrorHandling() throws {
    // --- README: Error handling ---
    func describe(_ data: Data) -> String {
        do {
            return try transcribe(musicXML: data)
        } catch TranscriptionError.unsupportedRootElement(let found) {
            return "Not a partwise score: found <\(found)>."
        } catch TranscriptionError.corruptedArchive(let why) {
            return "This .mxl file could not be read: \(why)"
        } catch TranscriptionError.malformedXML(let line, _) {
            return "Not well-formed XML, at line \(line)."
        } catch TranscriptionError.emptyScore {
            return "That file holds no music."
        } catch {
            return "Could not read that file: \(error)."
        }
    }
    // --- end ---

    #expect(describe(Data("<html/>".utf8)) == "Not a partwise score: found <html>.")
    var brokenArchive = Data([0x50, 0x4B, 0x03, 0x04])
    brokenArchive.append(Data(repeating: 0, count: 32))
    #expect(describe(brokenArchive).hasPrefix("This .mxl file could not be read:"))
}

@Test func readmeCompressedMusicXML() throws {
    let compressed = try mxlFixture("carmen.mxl")

    // --- README: Compressed .mxl ---
    // No special call needed — Score(musicXML:) detects the ZIP signature and
    // reads the archive's root entry transparently, exactly as if it had been
    // handed the uncompressed MusicXML directly.
    let text = try transcribe(musicXML: compressed)
    // --- end ---

    let uncompressed = try mxlFixture("carmen.musicxml")
    #expect(text == (try transcribe(musicXML: uncompressed)))
}

@Test func readmeInjectingNothing() throws {
    // --- README: No platform boundaries ---
    // The library takes Data and returns values. There is no file system, no
    // network, no clock and no randomness in it, so there is nothing to inject
    // and nothing to stub. The host app opens the file; Magnificat reads it.
    let data = try Fixture.named("parry-2-good-night.musicxml")
    let first = try transcribe(musicXML: data)
    let second = try transcribe(musicXML: data)
    // --- end ---

    #expect(first == second, "the same input always gives the same text")
}
