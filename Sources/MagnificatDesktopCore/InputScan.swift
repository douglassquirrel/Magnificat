import Foundation

/// One entry found in `FOLDER/in`. See `DESKTOP-SPEC.md` §6.
public struct ScannedFile: Sendable, Equatable {
    /// The file's location on disk.
    public var url: URL
    /// The file's name, as it appears in the folder.
    public var name: String
    /// True when the name ends `.musicxml` or `.mxl` (compressed MusicXML),
    /// matched case-insensitively. Named `isMusicXML` for both, since `.mxl`
    /// is itself part of the MusicXML format's own standard — a compressed
    /// serialization of the same document, not a different format.
    public var isMusicXML: Bool
}

/// Lists the direct contents of `folderIn`, sorted by name. **Non-recursive** —
/// only the folder's immediate contents. Every entry is listed, including
/// unsupported files and subdirectories, so the caller can show the operator
/// why something was skipped rather than silently dropping it.
///
/// Dotfiles (`.DS_Store` and similar Finder litter) are excluded — they are
/// never something an operator placed there on purpose.
public func scanInputFolder(_ folderIn: URL) throws -> [ScannedFile] {
    let names = try FileManager.default.contentsOfDirectory(atPath: folderIn.path)
    return names
        .filter { !$0.hasPrefix(".") }
        .sorted()
        .map { name in
            let lowercased = name.lowercased()
            return ScannedFile(
                url: folderIn.appendingPathComponent(name),
                name: name,
                isMusicXML: lowercased.hasSuffix(".musicxml") || lowercased.hasSuffix(".mxl"))
        }
}
