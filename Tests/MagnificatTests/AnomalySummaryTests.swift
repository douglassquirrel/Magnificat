import Foundation
import Testing
@testable import Magnificat

// Follow-up to SPEC.md §6.15: anomalies were reported via `Transcript.anomalies`
// for a caller to surface however it liked — the CLI to stderr, the desktop app
// to last-run.log. Claude Code, reading the delivered text output directly,
// asked for the same information embedded in that output itself. Built once
// here so MagnificatCLI and MagnificatDesktopCore both use it rather than each
// formatting anomalies on their own.

func anomaly(measure: String, detail: String) -> Anomaly {
    Anomaly(kind: .durationContradictsType, partID: "P1", measureNumber: measure, detail: detail)
}

@Test func anomalySummaryIsNilForACleanTranscript() {
    let transcript = Transcript(lines: [TranscriptLine(text: "Measure 1. C 5, quarter.", kind: .measure)])
    #expect(transcript.anomalySummary == nil)
}

@Test func anomalySummaryNamesOneAnomalyByItsMeasure() {
    let transcript = Transcript(
        lines: [TranscriptLine(text: "Measure 12. C 5, quarter.", kind: .measure)],
        anomalies: [anomaly(measure: "12", detail: "a note typed quarter lasts 6 divisions, "
                                                   + "where that value would be 4")])
    #expect(transcript.anomalySummary == """
    1 anomaly found in this file:
    Measure 12: a note typed quarter lasts 6 divisions, where that value would be 4
    """)
}

@Test func anomalySummaryListsEachAnomalyAndUsesThePlural() {
    let transcript = Transcript(
        lines: [],
        anomalies: [
            anomaly(measure: "12", detail: "a note typed quarter lasts 6 divisions, "
                                          + "where that value would be 4"),
            anomaly(measure: "45", detail: "a note is written on staff 3, but this part declares 2"),
        ])
    #expect(transcript.anomalySummary == """
    2 anomalies found in this file:
    Measure 12: a note typed quarter lasts 6 divisions, where that value would be 4
    Measure 45: a note is written on staff 3, but this part declares 2
    """)
}

let omrDisclaimer = "This text was produced by machine recognition of a scanned page "
    + "and may contain errors"

@Test func plainTextWithAnomalySummaryLeadsWithTheDisclaimerEvenWhenClean() {
    let transcript = Transcript(lines: [TranscriptLine(text: "Measure 1. C 5, quarter.", kind: .measure)])
    let expected = omrDisclaimer + "\n\nMeasure 1. C 5, quarter.\n"
    #expect(transcript.plainTextWithAnomalySummary == expected)
}

@Test func plainTextWithAnomalySummaryAppendsTheAnomalyListAfterTheDisclaimer() {
    let transcript = Transcript(
        lines: [TranscriptLine(text: "Measure 12. C 5, quarter.", kind: .measure)],
        anomalies: [anomaly(measure: "12", detail: "overfull")])

    let expected = omrDisclaimer + "\n"
        + "1 anomaly found in this file:\n"
        + "Measure 12: overfull\n"
        + "\n"
        + "Measure 12. C 5, quarter.\n"
    #expect(transcript.plainTextWithAnomalySummary == expected)
}

@Test func plainTextWithAnomalySummaryEndsWithExactlyOneNewline() {
    let transcript = Transcript(
        lines: [TranscriptLine(text: "Measure 1. C 5, quarter.", kind: .measure)],
        anomalies: [anomaly(measure: "1", detail: "overfull")])
    #expect(transcript.plainTextWithAnomalySummary.hasSuffix("\n"))
    #expect(!transcript.plainTextWithAnomalySummary.hasSuffix("\n\n"))
}

@Test func anomalySummaryObeysThePlainTextRulesToo() throws {
    // SPEC.md §6.1's ASCII-only rule applies to this too, now that it is
    // embedded directly in the delivered text output. Checked against a real
    // fixture's real anomalies (this is the exact file Cowork's own feedback
    // named — "2 anomalies for Dichterliebe" — not a hand-built one.
    let score = try Score(musicXML: mxlFixture("Dichterliebe01.musicxml"))
    let transcript = score.transcript()
    let summary = try #require(transcript.anomalySummary, "expected Dichterliebe01 to have anomalies")
    #expect(summary.unicodeScalars.allSatisfy { $0.isASCII })
    #expect(summary.hasPrefix("2 anomalies found in this file:"))
}
