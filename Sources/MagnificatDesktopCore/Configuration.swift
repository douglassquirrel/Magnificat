import Foundation

/// Everything MagnificatDesktop needs to know about where it reads and writes.
/// See `DESKTOP-SPEC.md` §5.
public struct DesktopConfiguration: Sendable, Equatable {
    /// The root folder. `folder/in` holds input files; `folder/out` holds output.
    public var folder: URL

    public init(folder: URL) {
        self.folder = folder
    }
}

/// What can go wrong reading, writing, or acting on the configuration.
public enum ConfigurationError: Error, Equatable {
    case cannotReadConfig(String)
    case cannotWriteConfig(String)
    case cannotCreateFolder(String)
}

/// Reads and writes `DesktopConfiguration` as JSON at a fixed, injectable path.
///
/// There is no folder picker anywhere in this app — `DESKTOP-SPEC.md` §5 — so this
/// is the only way FOLDER is set, besides the in-window text field that calls
/// `save` directly.
public enum ConfigurationStore {
    private struct JSONShape: Codable {
        var folder: String
    }

    /// Loads the configuration from `configFile`. If the file does not exist,
    /// `defaultFolder` is written there and returned, so the file always exists
    /// — and is discoverable by shell — after the first call.
    public static func load(from configFile: URL, defaultFolder: URL) throws -> DesktopConfiguration {
        guard FileManager.default.fileExists(atPath: configFile.path) else {
            let config = DesktopConfiguration(folder: defaultFolder)
            try save(config, to: configFile)
            return config
        }
        let data: Data
        do {
            data = try Data(contentsOf: configFile)
        } catch {
            throw ConfigurationError.cannotReadConfig(error.localizedDescription)
        }
        do {
            let shape = try JSONDecoder().decode(JSONShape.self, from: data)
            return DesktopConfiguration(folder: URL(fileURLWithPath: shape.folder))
        } catch {
            throw ConfigurationError.cannotReadConfig(error.localizedDescription)
        }
    }

    /// Writes `configuration` to `configFile`, creating intermediate directories
    /// as needed.
    public static func save(_ configuration: DesktopConfiguration, to configFile: URL) throws {
        do {
            try FileManager.default.createDirectory(
                at: configFile.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            let shape = JSONShape(folder: configuration.folder.path)
            let data = try JSONEncoder().encode(shape)
            try data.write(to: configFile)
        } catch {
            throw ConfigurationError.cannotWriteConfig(error.localizedDescription)
        }
    }

    /// Creates `folder/in` and `folder/out` if they do not already exist, using
    /// ordinary user-level file operations. **Never elevated** — a folder this
    /// cannot create (a read-only volume, no write permission) is reported as
    /// `.cannotCreateFolder`, never a permission prompt. `DESKTOP-SPEC.md` §5.
    public static func ensureFolders(for configuration: DesktopConfiguration) throws {
        for sub in ["in", "out"] {
            let url = configuration.folder.appendingPathComponent(sub)
            do {
                try FileManager.default.createDirectory(
                    at: url, withIntermediateDirectories: true)
            } catch {
                throw ConfigurationError.cannotCreateFolder(
                    "\(url.path): \(error.localizedDescription)")
            }
        }
    }
}
