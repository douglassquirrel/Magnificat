import Foundation

/// Reads a compressed `.mxl` file down to the plain MusicXML bytes it
/// contains, per the standard MusicXML compressed-file convention: a ZIP
/// archive whose `META-INF/container.xml` manifest names which entry is the
/// root score. See `SPEC.md`'s decision log for why this exists and why the
/// entry is located this way rather than guessed.
enum CompressedMusicXML {
    /// The bytes of the archive's root MusicXML document.
    static func extractRootMusicXML(from archive: Data) throws -> Data {
        let entries = try ZipReader.entries(in: archive)

        guard let containerEntry = entries.first(where: { $0.name == "META-INF/container.xml" })
        else {
            throw TranscriptionError.corruptedArchive(
                "no META-INF/container.xml — not a compressed MusicXML file")
        }
        let containerXML = try ZipReader.extract(containerEntry, from: archive)
        let rootPath = try rootFilePath(from: containerXML)

        guard let rootEntry = entries.first(where: { $0.name == rootPath }) else {
            throw TranscriptionError.corruptedArchive(
                "container.xml names \"\(rootPath)\" as the root file, but the archive has no such entry")
        }
        return try ZipReader.extract(rootEntry, from: archive)
    }

    /// Reads `<rootfile full-path="...">` out of `container.xml`. A small,
    /// purpose-built parser rather than the full `XMLParser` machinery
    /// `MusicXMLHandler` uses — this document is a few lines of fixed shape,
    /// not a MusicXML score, and does not warrant the same apparatus.
    private static func rootFilePath(from containerXML: Data) throws -> String {
        final class RootFileFinder: NSObject, XMLParserDelegate {
            var path: String?
            func parser(_ parser: XMLParser, didStartElement name: String,
                       namespaceURI: String?, qualifiedName: String?,
                       attributes: [String: String]) {
                if name == "rootfile", path == nil {
                    path = attributes["full-path"]
                }
            }
        }
        let finder = RootFileFinder()
        let parser = XMLParser(data: containerXML)
        parser.delegate = finder
        parser.shouldResolveExternalEntities = false
        guard parser.parse(), let path = finder.path else {
            throw TranscriptionError.corruptedArchive(
                "container.xml has no <rootfile full-path=\"...\"/>")
        }
        return path
    }
}
