import Foundation
import Compression

/// One file inside a ZIP archive, as recorded in the central directory.
struct ZipEntry: Sendable, Equatable {
    var name: String
    /// `0` = stored (no compression), `8` = deflate. Every other value is
    /// rejected when the entry is extracted — real `.mxl` files use only
    /// these two, and supporting the rest of the ZIP method registry for a
    /// MusicXML container would be effort spent on files that do not occur.
    var compressionMethod: UInt16
    var compressedSize: Int
    var uncompressedSize: Int
    /// Byte offset of this entry's *local* file header — distinct from, and
    /// not always identical in layout to, its central-directory record.
    var localHeaderOffset: Int
}

/// A minimal ZIP reader: enough to enumerate entries and extract one by name
/// from a `.mxl` file. Not a general-purpose ZIP library — no ZIP64 (real
/// `.mxl` files are small XML documents, never near the 4 GB/65535-entry
/// threshold that requires it), no write support, no archive comment beyond
/// what is needed to locate the end-of-central-directory record.
///
/// Foundation has no ZIP API. `Compression` (Apple's system framework, present
/// identically on iOS and macOS since long before this library's platform
/// floor) supplies raw DEFLATE decompression — exactly what a ZIP entry's
/// compressed bytes are, with no zlib or gzip wrapper. Using it here is a
/// deliberate, documented exception to "Foundation only": `Compression` is not
/// a UI framework and not a third-party dependency, and it is what makes
/// `.mxl` support possible without either. See `SPEC.md`'s decision log.
enum ZipReader {
    private static let endOfCentralDirectorySignature: UInt32 = 0x0605_4B50
    private static let centralDirectoryFileHeaderSignature: UInt32 = 0x0201_4B50
    private static let localFileHeaderSignature: UInt32 = 0x0403_4B50

    /// Every entry recorded in the archive's central directory.
    static func entries(in data: Data) throws -> [ZipEntry] {
        let eocd = try findEndOfCentralDirectory(in: data)
        var offset = eocd.centralDirectoryOffset
        var entries: [ZipEntry] = []
        entries.reserveCapacity(eocd.entryCount)

        for _ in 0..<eocd.entryCount {
            let (entry, recordLength) = try readCentralDirectoryRecord(in: data, at: offset)
            entries.append(entry)
            offset += recordLength
        }
        return entries
    }

    /// The decompressed bytes of `entry`.
    static func extract(_ entry: ZipEntry, from data: Data) throws -> Data {
        let base = data.startIndex + entry.localHeaderOffset
        guard let signature = readUInt32(data, at: base), signature == localFileHeaderSignature
        else {
            throw TranscriptionError.corruptedArchive(
                "no local file header at the offset the central directory recorded for \(entry.name)")
        }
        // Not covered by a test: this fires only when the central directory
        // (which must itself be intact for extract() to be reached at all —
        // ZipReader.entries(in:) runs first) points at a local header whose
        // signature is valid but whose fixed fields past it are cut off.
        // Isolating that combination needs a contrived byte layout — the
        // archive must stay large enough for the central directory and EOCD
        // to parse, while this one entry's header alone is short — with no
        // single natural truncation point that produces it. Left in as real
        // defense against a partially corrupted archive.
        guard let nameLength = readUInt16(data, at: base + 26),
              let extraLength = readUInt16(data, at: base + 28)
        else {
            throw TranscriptionError.corruptedArchive("truncated local file header for \(entry.name)")
        }
        let dataStart = base + 30 + Int(nameLength) + Int(extraLength)
        guard dataStart + entry.compressedSize <= data.endIndex else {
            throw TranscriptionError.corruptedArchive("\(entry.name) runs past the end of the archive")
        }
        let compressed = data.subdata(in: dataStart..<(dataStart + entry.compressedSize))

        switch entry.compressionMethod {
        case 0:
            return compressed
        case 8:
            return try inflate(compressed, uncompressedSize: entry.uncompressedSize, name: entry.name)
        default:
            throw TranscriptionError.corruptedArchive(
                "\(entry.name) uses ZIP compression method \(entry.compressionMethod), which this reader does not support")
        }
    }

    // MARK: - End of central directory

    private struct EndOfCentralDirectory {
        var entryCount: Int
        var centralDirectoryOffset: Int
    }

    /// Scans backward from the end of the archive for the EOCD signature. A
    /// ZIP archive may carry a trailing comment of up to 65,535 bytes after
    /// the record, so the search window is the record's own fixed size (22
    /// bytes) plus that maximum.
    private static func findEndOfCentralDirectory(in data: Data) throws -> EndOfCentralDirectory {
        let minimumRecordSize = 22
        guard data.count >= minimumRecordSize else {
            throw TranscriptionError.corruptedArchive("too small to be a ZIP archive")
        }
        let searchWindow = min(data.count, minimumRecordSize + 65_535)
        let searchStart = data.endIndex - searchWindow

        var position = data.endIndex - minimumRecordSize
        while position >= searchStart {
            if readUInt32(data, at: position) == endOfCentralDirectorySignature {
                guard let entryCount = readUInt16(data, at: position + 10),
                      let cdOffset = readUInt32(data, at: position + 16)
                else { break }
                return EndOfCentralDirectory(entryCount: Int(entryCount),
                                             centralDirectoryOffset: Int(cdOffset))
            }
            position -= 1
        }
        throw TranscriptionError.corruptedArchive("no end-of-central-directory record found")
    }

    // MARK: - Central directory

    /// Returns the parsed entry and the total byte length of its record, so
    /// the caller can advance to the next one.
    private static func readCentralDirectoryRecord(in data: Data, at offset: Int) throws -> (ZipEntry, Int) {
        let base = data.startIndex + offset
        guard readUInt32(data, at: base) == centralDirectoryFileHeaderSignature else {
            throw TranscriptionError.corruptedArchive("central directory is inconsistent with its own entry count")
        }
        guard let method = readUInt16(data, at: base + 10),
              let compressedSize = readUInt32(data, at: base + 20),
              let uncompressedSize = readUInt32(data, at: base + 24),
              let nameLength = readUInt16(data, at: base + 28),
              let extraLength = readUInt16(data, at: base + 30),
              let commentLength = readUInt16(data, at: base + 32),
              let localHeaderOffset = readUInt32(data, at: base + 42)
        else {
            throw TranscriptionError.corruptedArchive("truncated central directory record")
        }

        // Not covered by a test: every real ZIP writer, including every
        // fixture and this file's own test-only archive builder, writes
        // entry names as valid UTF-8 (ASCII in practice). Provoking this
        // needs injecting raw invalid bytes into a name field directly,
        // bypassing the test builder's String-typed entries entirely, for a
        // scenario no real .mxl exporter produces. Left in rather than
        // trusting String(data:encoding:) to always succeed.
        let nameStart = base + 46
        guard let name = readString(data, at: nameStart, length: Int(nameLength)) else {
            throw TranscriptionError.corruptedArchive("central directory entry name is not valid text")
        }

        let recordLength = 46 + Int(nameLength) + Int(extraLength) + Int(commentLength)
        let entry = ZipEntry(name: name, compressionMethod: method,
                             compressedSize: Int(compressedSize),
                             uncompressedSize: Int(uncompressedSize),
                             localHeaderOffset: Int(localHeaderOffset))
        return (entry, recordLength)
    }

    // MARK: - Decompression

    /// Raw DEFLATE (RFC 1951) — a ZIP entry's compressed bytes carry no zlib
    /// or gzip framing of their own.
    private static func inflate(_ compressed: Data, uncompressedSize: Int, name: String) throws -> Data {
        guard uncompressedSize > 0 else { return Data() }
        var output = Data(count: uncompressedSize)
        let written = output.withUnsafeMutableBytes { outputBuffer -> Int in
            compressed.withUnsafeBytes { inputBuffer -> Int in
                guard let outputBase = outputBuffer.bindMemory(to: UInt8.self).baseAddress,
                      let inputBase = inputBuffer.bindMemory(to: UInt8.self).baseAddress
                else { return 0 }
                return compression_decode_buffer(outputBase, uncompressedSize,
                                                 inputBase, compressed.count,
                                                 nil, COMPRESSION_ZLIB)
            }
        }
        guard written == uncompressedSize else {
            throw TranscriptionError.corruptedArchive(
                "\(name) did not decompress to its recorded size (got \(written), expected \(uncompressedSize))")
        }
        return output
    }

    // MARK: - Little-endian field reads

    private static func readUInt16(_ data: Data, at index: Int) -> UInt16? {
        guard index >= data.startIndex, index + 2 <= data.endIndex else { return nil }
        return UInt16(data[index]) | (UInt16(data[index + 1]) << 8)
    }

    private static func readUInt32(_ data: Data, at index: Int) -> UInt32? {
        guard index >= data.startIndex, index + 4 <= data.endIndex else { return nil }
        return UInt32(data[index]) | (UInt32(data[index + 1]) << 8)
             | (UInt32(data[index + 2]) << 16) | (UInt32(data[index + 3]) << 24)
    }

    private static func readString(_ data: Data, at index: Int, length: Int) -> String? {
        guard index >= data.startIndex, index + length <= data.endIndex else { return nil }
        return String(data: data.subdata(in: index..<(index + length)), encoding: .utf8)
    }
}
