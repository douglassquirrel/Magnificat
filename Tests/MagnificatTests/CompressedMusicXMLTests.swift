import Foundation
import Compression
import Testing
@testable import Magnificat

// SPEC.md — compressed .mxl support, added 28 August 2026. Real fixtures
// throughout: Tests/MagnificatTests/Fixtures/mxl/README.md documents that each
// pair was confirmed byte-identical (unzip -p vs the .musicxml sibling) before
// being used, so a passing round-trip test here proves real correctness, not
// agreement with a synthetic zip built to match the implementation.

func mxlFixture(_ name: String) throws -> Data {
    try Data(contentsOf: Bundle.module.url(forResource: "Fixtures/mxl/\(name)", withExtension: nil)!)
}

@Test func extractsTheContainerXMLEntryFromARealMxl() throws {
    let data = try mxlFixture("carmen.mxl")
    let entries = try ZipReader.entries(in: data)
    let container = try #require(entries.first { $0.name == "META-INF/container.xml" })
    let extracted = try ZipReader.extract(container, from: data)
    let text = String(decoding: extracted, as: UTF8.self)
    #expect(text.contains(#"full-path="carmen.xml""#))
}

@Test func extractsTheRootEntryMatchingItsUncompressedSiblingExactly() throws {
    for (mxlName, xmlName) in [("carmen.mxl", "carmen.musicxml"),
                               ("carmen-degraded.mxl", "carmen-degraded.musicxml"),
                               ("Dichterliebe01.mxl", "Dichterliebe01.musicxml")] {
        let extracted = try CompressedMusicXML.extractRootMusicXML(from: mxlFixture(mxlName))
        let expected = try mxlFixture(xmlName)
        #expect(extracted == expected, "\(mxlName) did not extract to match \(xmlName) exactly")
    }
}

// SPEC.md — every distinct failure ZipReader/CompressedMusicXML can report
// gets its own test, provoked directly rather than guessed at: real .mxl
// exporters only ever produce DEFLATE entries and well-formed archives, so
// the STORED method and every corruption case below need to be built by
// hand, the same way the parser's own edge-case tests build small MusicXML
// documents inline rather than hunting for a real file that happens to be
// broken in the right way.

/// Builds a minimal, well-formed ZIP archive from `entries`, each stored with
/// its own compression method (`0` = stored, `8` = deflate). `declaredSize`,
/// when given, overrides what the local and central headers *claim* the
/// uncompressed size is — independent of `content`'s real size, so a test can
/// build an archive that lies about it without hand-assembling one.
func buildZip(_ entries: [(name: String, content: Data, method: UInt16, declaredSize: Int?)]) -> Data {
    var body = Data()
    var centralDirectory = Data()

    func appendUInt16(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
    }
    func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 24) & 0xFF))
    }

    for entry in entries {
        let nameBytes = Data(entry.name.utf8)
        let uncompressedSize = UInt32(entry.declaredSize ?? entry.content.count)
        let stored: Data
        if entry.method == 8 {
            let capacity = entry.content.count + 256
            var output = Data(count: capacity)
            let written = output.withUnsafeMutableBytes { outBuf -> Int in
                entry.content.withUnsafeBytes { inBuf -> Int in
                    compression_encode_buffer(
                        outBuf.bindMemory(to: UInt8.self).baseAddress!, capacity,
                        inBuf.bindMemory(to: UInt8.self).baseAddress!, entry.content.count,
                        nil, COMPRESSION_ZLIB)
                }
            }
            stored = output.prefix(written)
        } else {
            stored = entry.content
        }

        let localHeaderOffset = UInt32(body.count)
        appendUInt32(0x0403_4B50, to: &body)          // local file header signature
        appendUInt16(20, to: &body)                    // version needed
        appendUInt16(0, to: &body)                     // flags
        appendUInt16(entry.method, to: &body)
        appendUInt16(0, to: &body)                     // mod time
        appendUInt16(0, to: &body)                     // mod date
        appendUInt32(0, to: &body)                      // crc32 (unused by this reader)
        appendUInt32(UInt32(stored.count), to: &body)   // compressed size
        appendUInt32(uncompressedSize, to: &body)             // uncompressed size
        appendUInt16(UInt16(nameBytes.count), to: &body)
        appendUInt16(0, to: &body)                      // extra field length
        body.append(nameBytes)
        body.append(stored)

        appendUInt32(0x0201_4B50, to: &centralDirectory)  // central directory signature
        appendUInt16(20, to: &centralDirectory)            // version made by
        appendUInt16(20, to: &centralDirectory)            // version needed
        appendUInt16(0, to: &centralDirectory)              // flags
        appendUInt16(entry.method, to: &centralDirectory)
        appendUInt16(0, to: &centralDirectory)              // mod time
        appendUInt16(0, to: &centralDirectory)              // mod date
        appendUInt32(0, to: &centralDirectory)               // crc32
        appendUInt32(UInt32(stored.count), to: &centralDirectory)
        appendUInt32(uncompressedSize, to: &centralDirectory)
        appendUInt16(UInt16(nameBytes.count), to: &centralDirectory)
        appendUInt16(0, to: &centralDirectory)  // extra field length
        appendUInt16(0, to: &centralDirectory)  // comment length
        appendUInt16(0, to: &centralDirectory)  // disk number start
        appendUInt16(0, to: &centralDirectory)  // internal attrs
        appendUInt32(0, to: &centralDirectory)   // external attrs
        appendUInt32(localHeaderOffset, to: &centralDirectory)
        centralDirectory.append(nameBytes)
    }

    let centralDirectoryOffset = UInt32(body.count)
    var archive = body
    archive.append(centralDirectory)
    appendUInt32(0x0605_4B50, to: &archive)   // end of central directory signature
    appendUInt16(0, to: &archive)              // disk number
    appendUInt16(0, to: &archive)              // disk with CD
    appendUInt16(UInt16(entries.count), to: &archive)
    appendUInt16(UInt16(entries.count), to: &archive)
    appendUInt32(UInt32(centralDirectory.count), to: &archive)
    appendUInt32(centralDirectoryOffset, to: &archive)
    appendUInt16(0, to: &archive)  // comment length
    return archive
}

let sampleContainerXML = Data("""
<?xml version="1.0" encoding="UTF-8"?>
<container><rootfiles>
  <rootfile full-path="score.xml" media-type="application/vnd.recordare.musicxml+xml"/>
</rootfiles></container>
""".utf8)

func expectCorruptedArchive(_ archive: Data, contains fragment: String,
                            sourceLocation: SourceLocation = #_sourceLocation) throws {
    let error = #expect(throws: TranscriptionError.self, sourceLocation: sourceLocation) {
        _ = try Score(musicXML: archive)
    }
    guard case .corruptedArchive(let reason) = try #require(error, sourceLocation: sourceLocation) else {
        Issue.record("expected .corruptedArchive, got \(String(describing: error))",
                     sourceLocation: sourceLocation)
        return
    }
    #expect(reason.contains(fragment), sourceLocation: sourceLocation)
}

@Test func aStoredUncompressedEntryExtractsUnchanged() throws {
    let score = Data("<x/>".utf8)
    let archive = buildZip([
        ("META-INF/container.xml", sampleContainerXML, 8, nil),
        ("score.xml", score, 0, nil),   // stored — no compression
    ])
    let extracted = try CompressedMusicXML.extractRootMusicXML(from: archive)
    #expect(extracted == score)
}

@Test func anUnsupportedCompressionMethodIsReported() throws {
    let archive = buildZip([
        ("META-INF/container.xml", sampleContainerXML, 8, nil),
        ("score.xml", Data("<x/>".utf8), 12, nil),   // 12 = BZIP2, not supported
    ])
    try expectCorruptedArchive(archive, contains: "compression method 12")
}

@Test func aMissingContainerXMLIsReported() throws {
    let archive = buildZip([("score.xml", Data("<x/>".utf8), 8, nil)])
    try expectCorruptedArchive(archive, contains: "no META-INF/container.xml")
}

@Test func aContainerXMLNamingAMissingRootFileIsReported() throws {
    let archive = buildZip([("META-INF/container.xml", sampleContainerXML, 8, nil)])
    try expectCorruptedArchive(archive, contains: "no such entry")
}

@Test func aContainerXMLWithNoRootfileElementIsReported() throws {
    let archive = buildZip([
        ("META-INF/container.xml", Data("<container><rootfiles/></container>".utf8), 8, nil),
    ])
    try expectCorruptedArchive(archive, contains: "no <rootfile")
}

@Test func dataTooSmallToBeAZipIsReported() throws {
    try expectCorruptedArchive(Data([0x50, 0x4B, 0x03, 0x04]), contains: "too small")
}

@Test func aCentralDirectoryWithAWrongSignatureIsReported() throws {
    var archive = buildZip([("META-INF/container.xml", sampleContainerXML, 8, nil)])
    // The central directory's offset is correct, but the four signature bytes
    // there have been corrupted — distinct from a record merely running out
    // of bytes (aTruncatedCentralDirectoryRecordIsReported, below).
    guard let range = archive.range(of: Data([0x50, 0x4B, 0x01, 0x02])) else {
        Issue.record("test setup: could not find the central directory signature to corrupt")
        return
    }
    archive[range.lowerBound] = 0xFF
    try expectCorruptedArchive(Data(archive), contains: "inconsistent with its own entry count")
}

@Test func aTruncatedCentralDirectoryRecordIsReported() throws {
    // The signature is intact, but the record's fixed 46-byte header is cut
    // short. The EOCD must still correctly follow, or the reader would report
    // a missing EOCD instead of ever reaching the central directory at all —
    // so the EOCD's own central-directory-size field is corrected to match
    // the now-shorter directory, exactly as a real truncated-in-transit
    // archive would still have *a* trailing EOCD, just one describing more
    // data than actually survived.
    var archive = buildZip([("META-INF/container.xml", sampleContainerXML, 8, nil)])
    guard let signatureStart = archive.range(of: Data([0x50, 0x4B, 0x01, 0x02]))?.lowerBound else {
        Issue.record("test setup: could not find the central directory signature")
        return
    }
    let truncatedCentralDirectory = archive[signatureStart..<(signatureStart + 20)]
    var rebuilt = archive[archive.startIndex..<signatureStart]
    let cdOffset = UInt32(rebuilt.count)
    rebuilt.append(contentsOf: truncatedCentralDirectory)
    let cdSize = UInt32(truncatedCentralDirectory.count)

    func u16(_ v: UInt16) { rebuilt.append(UInt8(v & 0xFF)); rebuilt.append(UInt8(v >> 8)) }
    func u32(_ v: UInt32) {
        rebuilt.append(UInt8(v & 0xFF)); rebuilt.append(UInt8((v >> 8) & 0xFF))
        rebuilt.append(UInt8((v >> 16) & 0xFF)); rebuilt.append(UInt8((v >> 24) & 0xFF))
    }
    u32(0x0605_4B50); u16(0); u16(0); u16(1); u16(1); u32(cdSize); u32(cdOffset); u16(0)

    try expectCorruptedArchive(Data(rebuilt), contains: "truncated central directory record")
}

@Test func aLocalHeaderWithAWrongSignatureIsReported() throws {
    // Corrupting the *second* entry's local header, not the first: the first
    // entry's local header signature sits at offset 0, which doubles as
    // Score.init's own outer "is this even a zip" check — corrupting it there
    // makes the file stop looking like a zip at all, so Score.init correctly
    // falls through to parsing it as plain (and then malformed) XML instead
    // of ever reaching ZipReader. That was tried first and is a real, sound
    // behavior, just not the one this test means to provoke.
    var archive = buildZip([
        ("META-INF/container.xml", sampleContainerXML, 8, nil),
        ("score.xml", Data("<x/>".utf8), 8, nil),
    ])
    guard let secondHeaderOffset = archive.range(of: Data([0x50, 0x4B, 0x03, 0x04]),
                                                  in: (archive.startIndex + 1)..<archive.endIndex)?
        .lowerBound
    else {
        Issue.record("test setup: could not find the second entry's local header")
        return
    }
    archive[secondHeaderOffset] = 0xFF
    try expectCorruptedArchive(Data(archive), contains: "no local file header")
}

@Test func entryDataRunningPastTheArchiveIsReported() throws {
    // A central directory that claims a compressed size larger than what
    // actually follows — as if the archive were cut off mid-entry.
    var archive = buildZip([("META-INF/container.xml", sampleContainerXML, 8, nil)])
    guard let sizeFieldStart = archive.range(of: Data([0x50, 0x4B, 0x01, 0x02]))
        .map({ $0.lowerBound + 20 })   // central directory record: compressed size at +20
    else {
        Issue.record("test setup: could not find the central directory signature")
        return
    }
    let hugeSize: UInt32 = 0xFFFF_FF00
    archive[sizeFieldStart] = UInt8(hugeSize & 0xFF)
    archive[sizeFieldStart + 1] = UInt8((hugeSize >> 8) & 0xFF)
    archive[sizeFieldStart + 2] = UInt8((hugeSize >> 16) & 0xFF)
    archive[sizeFieldStart + 3] = UInt8((hugeSize >> 24) & 0xFF)
    try expectCorruptedArchive(Data(archive), contains: "runs past the end of the archive")
}

@Test func aDecompressionSizeMismatchIsReported() throws {
    // Declares an uncompressed size the DEFLATE stream does not actually
    // decode to — buildZip's declaredSize override exists for exactly this,
    // since by construction it otherwise always tells the truth about size.
    let content = sampleContainerXML
    let archive = buildZip([
        ("META-INF/container.xml", content, 8, content.count + 1000),
    ])
    try expectCorruptedArchive(archive, contains: "did not decompress to its recorded size")
}

