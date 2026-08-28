import Foundation
import Testing
@testable import MagnificatDesktopCore

// DESKTOP-SPEC.md §5 — FOLDER is read from a JSON config file at a fixed path, or
// defaulted and written on first launch. Every test injects its own temp URLs so
// the real home directory is never touched — CLAUDE.md's hermetic-test rule.

/// A fresh, empty temporary directory, removed after the test.
func tempDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("magnificat-desktop-test-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func writesTheDefaultFolderWhenNoConfigFileExists() throws {
    let base = tempDirectory()
    defer { try? FileManager.default.removeItem(at: base) }
    let configFile = base.appendingPathComponent("config.json")
    let defaultFolder = base.appendingPathComponent("MagnificatDesktop")

    let config = try ConfigurationStore.load(from: configFile, defaultFolder: defaultFolder)

    #expect(config.folder == defaultFolder)
    #expect(FileManager.default.fileExists(atPath: configFile.path),
            "the default should be written back so it is discoverable by shell")
}

@Test func readsAnExistingConfigFile() throws {
    let base = tempDirectory()
    defer { try? FileManager.default.removeItem(at: base) }
    let configFile = base.appendingPathComponent("config.json")
    let chosen = base.appendingPathComponent("SomewhereElse")
    try FileManager.default.createDirectory(at: chosen, withIntermediateDirectories: true)
    try Data(#"{"folder": "\#(chosen.path)"}"#.utf8).write(to: configFile)

    let config = try ConfigurationStore.load(from: configFile, defaultFolder: base.appendingPathComponent("unused"))

    #expect(config.folder.path == chosen.path)
}

@Test func savingWritesReadableJSON() throws {
    let base = tempDirectory()
    defer { try? FileManager.default.removeItem(at: base) }
    let configFile = base.appendingPathComponent("config.json")
    let folder = base.appendingPathComponent("Chosen")

    try ConfigurationStore.save(DesktopConfiguration(folder: folder), to: configFile)
    let reloaded = try ConfigurationStore.load(from: configFile, defaultFolder: base)

    #expect(reloaded.folder.path == folder.path)
}

// DESKTOP-SPEC.md §5 — FOLDER/in and FOLDER/out are created on launch and on every
// folder change, using ordinary user-level operations. Never elevated; a failure
// is reported, never a permission prompt.

@Test func createsInAndOutWhenTheyDoNotExist() throws {
    let base = tempDirectory()
    defer { try? FileManager.default.removeItem(at: base) }
    let folder = base.appendingPathComponent("Fresh")
    let config = DesktopConfiguration(folder: folder)

    try ConfigurationStore.ensureFolders(for: config)

    var isDir: ObjCBool = false
    #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("in").path, isDirectory: &isDir))
    #expect(isDir.boolValue)
    #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("out").path, isDirectory: &isDir))
    #expect(isDir.boolValue)
}

@Test func leavesExistingFilesInAlreadyPresentFolders() throws {
    // Ensuring the folders exist must never touch what is already there.
    let base = tempDirectory()
    defer { try? FileManager.default.removeItem(at: base) }
    let folder = base.appendingPathComponent("Existing")
    let inDir = folder.appendingPathComponent("in")
    try FileManager.default.createDirectory(at: inDir, withIntermediateDirectories: true)
    let marker = inDir.appendingPathComponent("already-here.musicxml")
    try Data("<x/>".utf8).write(to: marker)

    try ConfigurationStore.ensureFolders(for: DesktopConfiguration(folder: folder))

    #expect(FileManager.default.fileExists(atPath: marker.path))
}

@Test func reportsAnUncreatableFolderRatherThanCrashingOrPrompting() throws {
    // A file where a directory is needed can never be turned into a directory —
    // this stands in for "the path is not writable" without needing real
    // permission games, and proves the failure surfaces as a typed error rather
    // than a crash, an exception the caller cannot catch, or (worse) a prompt.
    let base = tempDirectory()
    defer { try? FileManager.default.removeItem(at: base) }
    let blocked = base.appendingPathComponent("blocked")
    try Data("not a directory".utf8).write(to: blocked)

    #expect(throws: ConfigurationError.self) {
        try ConfigurationStore.ensureFolders(for: DesktopConfiguration(folder: blocked))
    }
}
