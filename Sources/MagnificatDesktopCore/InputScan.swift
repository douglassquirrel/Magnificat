import Foundation

/// One entry found in `FOLDER/in`. See `DESKTOP-SPEC.md` §6.
public struct ScannedFile: Sendable, Equatable {
    /// The file's location on disk.
    public var url: URL
    /// The file's name, as it appears in the folder.
    public var name: String
    /// True when the name ends `.musicxml`, matched case-insensitively.
    public var isMusicXML: Bool
}

/// Lists the direct contents of `folderIn`, sorted by name. **Non-recursive** —
/// only the folder's immediate contents. Every entry is listed, including
/// non-`.musicxml` files and subdirectories, so the caller can show the operator
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
            ScannedFile(
                url: folderIn.appendingPathComponent(name),
                name: name,
                isMusicXML: name.lowercased().hasSuffix(".musicxml"))
        }
}
