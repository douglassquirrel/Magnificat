import Foundation
import Testing
@testable import Magnificat

/// The real MusicXML files, loaded from the test bundle.
enum Fixture {
    static let directories = ["openscore", "omr-output", "omr-ground-truth"]

    static var all: [(name: String, data: Data)] {
        directories.flatMap { directory -> [(String, Data)] in
            guard let base = Bundle.module.url(forResource: "Fixtures", withExtension: nil)?
                .appendingPathComponent(directory),
                  let names = try? FileManager.default.contentsOfDirectory(atPath: base.path)
            else { return [] }
            return names.filter { $0.hasSuffix(".musicxml") }.sorted().compactMap { name in
                guard let data = try? Data(contentsOf: base.appendingPathComponent(name))
                else { return nil }
                return (name, data)
            }
        }
    }

    static func named(_ name: String) throws -> Data {
        let match = try #require(all.first { $0.name == name }, "no fixture named \(name)")
        return match.data
    }
}

@Test func theFixturesAreAllPresent() {
    // 12 OpenScore + 13 OMR output + 6 OMR ground truth.
    #expect(Fixture.all.count == 31)
}

@Test func everyFixtureParsesWithoutThrowing() throws {
    for (name, data) in Fixture.all {
        #expect(throws: Never.self, "\(name) should parse") {
            _ = try Score(musicXML: data)
        }
    }
}

@Test func everyFixtureYieldsPartsMeasuresAndNotes() throws {
    for (name, data) in Fixture.all {
        let score = try Score(musicXML: data)
        #expect(!score.parts.isEmpty, "\(name) has no parts")
        for part in score.parts {
            #expect(!part.measures.isEmpty, "\(name) part \(part.id) has no measures")
        }
        let notes = score.parts.flatMap(\.measures).flatMap(\.events).filter {
            if case .note = $0 { return true }
            return false
        }
        #expect(!notes.isEmpty, "\(name) has no notes")
    }
}

@Test func readsTheMayerWithTheStructureTheFileActuallyHas() throws {
    let score = try Score(musicXML: Fixture.named("mayer-1-du-bist-wie-eine-blume.musicxml"))
    #expect(score.parts.count == 2)
    // 32 measures per part — the file holds 64 <measure> elements across two parts.
    #expect(score.parts.allSatisfy { $0.measures.count == 32 })
    #expect(score.parts[0].name == "Singstimme, Voice")
    #expect(score.parts[1].name == "Pianoforte")
}

/// The OpenScore manifest, which records counts computed independently of this
/// library. Cross-checking against it is the strongest parser test available:
/// the numbers were not derived from Magnificat and cannot drift to match it.
struct ManifestEntry: Decodable {
    var file: String
    var measures: Int
    var notes: Int
    var key_fifths: Int
}

func openScoreManifest() throws -> [ManifestEntry] {
    let url = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        .appendingPathComponent("openscore/manifest.json")
    return try JSONDecoder().decode([ManifestEntry].self, from: Data(contentsOf: url))
}

@Test func noteCountsMatchTheIndependentlyRecordedManifest() throws {
    // The manifest counts pitched notes and excludes grace notes. Verified against
    // all twelve entries before this test was written.
    for entry in try openScoreManifest() {
        let name = String(entry.file.split(separator: "/").last!)
        let score = try Score(musicXML: Fixture.named(name))
        let counted = score.parts.flatMap(\.measures).flatMap(\.events).filter { event in
            guard case .note(let note) = event else { return false }
            return !note.isGrace
        }.count
        #expect(counted == entry.notes, "\(name): parsed \(counted), manifest says \(entry.notes)")
    }
}

@Test func measureCountsMatchTheIndependentlyRecordedManifest() throws {
    for entry in try openScoreManifest() {
        let name = String(entry.file.split(separator: "/").last!)
        let score = try Score(musicXML: Fixture.named(name))
        for part in score.parts {
            #expect(part.measures.count == entry.measures,
                    "\(name) part \(part.id): \(part.measures.count) vs \(entry.measures)")
        }
    }
}

@Test func backupPlacesBothHandsOfARealGrandStaffAtTheStartOfTheMeasure() throws {
    // Verifies on real data what the synthetic backup test verifies synthetically.
    // Without <backup> handling the left hand would start after the right hand
    // ended, rather than alongside it.
    let score = try Score(musicXML: Fixture.named("mayer-1-du-bist-wie-eine-blume.musicxml"))
    let piano = try #require(score.parts.last)
    let measure = try #require(piano.measures.first)

    let rightHand = measure.events.filter { $0.staff == 1 }
    let leftHand = measure.events.filter { $0.staff == 2 }
    #expect(!rightHand.isEmpty)
    #expect(!leftHand.isEmpty)
    #expect(rightHand.first?.onset == 0)
    #expect(leftHand.first?.onset == 0, "the left hand must start with the right, not after it")
}

@Test func everyEventOnsetStaysInsideItsMeasure() throws {
    // A negative onset would mean a backup ran past the start of the measure.
    for (name, data) in Fixture.all {
        let score = try Score(musicXML: data)
        for part in score.parts {
            for measure in part.measures where measure.events.contains(where: { $0.onset < 0 }) {
                Issue.record("\(name) part \(part.id) measure \(measure.number) has a negative onset")
            }
        }
    }
}
