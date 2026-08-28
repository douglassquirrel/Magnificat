import Foundation
import Testing
@testable import MagnificatDesktopCore
@testable import MagnificatDesktop

// The ViewModel is the one piece of MagnificatDesktop with real logic — config
// resolution, folder validation, guarding concurrent runs — so it gets tests
// exactly like MagnificatCLI's Invocation does. The SwiftUI View itself renders
// only what this hands it and is not separately unit tested, mirroring how
// MagnificatCLI's three-line main.swift is not tested on its own.

@MainActor
func makeViewModel(defaultFolder: URL? = nil) -> (AppViewModel, base: URL) {
    let base = tempDirectory()
    let configFile = base.appendingPathComponent("config.json")
    let folder = defaultFolder ?? base.appendingPathComponent("MagnificatDesktop")
    let viewModel = AppViewModel(configFileURL: configFile, defaultFolder: folder)
    return (viewModel, base)
}

@Test @MainActor func initReadsOrDefaultsTheConfiguredFolder() {
    let (viewModel, base) = makeViewModel()
    defer { try? FileManager.default.removeItem(at: base) }

    #expect(viewModel.folderText == base.appendingPathComponent("MagnificatDesktop").path)
}

@Test @MainActor func initScansWhateverIsAlreadyInFolder() throws {
    let base = tempDirectory()
    defer { try? FileManager.default.removeItem(at: base) }
    let folder = base.appendingPathComponent("Existing")
    let inDir = folder.appendingPathComponent("in")
    try FileManager.default.createDirectory(at: inDir, withIntermediateDirectories: true)
    try Data().write(to: inDir.appendingPathComponent("song.musicxml"))

    let viewModel = AppViewModel(configFileURL: base.appendingPathComponent("config.json"),
                                 defaultFolder: folder)

    #expect(viewModel.scanned.map(\.name) == ["song.musicxml"])
}

@Test @MainActor func canRunIsTrueWhileIdle() {
    let (viewModel, base) = makeViewModel()
    defer { try? FileManager.default.removeItem(at: base) }
    #expect(viewModel.canRun)
    #expect(viewModel.isRunning == false)
}

@Test @MainActor func useFolderPersistsAndRescans() throws {
    let (viewModel, base) = makeViewModel()
    defer { try? FileManager.default.removeItem(at: base) }
    let newFolder = base.appendingPathComponent("Elsewhere")
    try FileManager.default.createDirectory(
        at: newFolder.appendingPathComponent("in"), withIntermediateDirectories: true)
    try Data().write(to: newFolder.appendingPathComponent("in/piece.musicxml"))

    viewModel.useFolder(newFolder.path)

    #expect(viewModel.folderText == newFolder.path)
    #expect(viewModel.scanned.map(\.name) == ["piece.musicxml"])
    #expect(viewModel.folderErrorMessage == nil)
}

@Test @MainActor func useFolderReportsAnErrorRatherThanCrashingOrPrompting() throws {
    let (viewModel, base) = makeViewModel()
    defer { try? FileManager.default.removeItem(at: base) }
    let blocked = base.appendingPathComponent("blocked-file")
    try Data("not a directory".utf8).write(to: blocked)

    viewModel.useFolder(blocked.path)

    #expect(viewModel.folderErrorMessage != nil)
}

@Test @MainActor func runProducesAResultAndReturnsToIdle() async throws {
    let base = tempDirectory()
    defer { try? FileManager.default.removeItem(at: base) }
    let folder = base.appendingPathComponent("Work")
    let inDir = folder.appendingPathComponent("in")
    try FileManager.default.createDirectory(at: inDir, withIntermediateDirectories: true)
    try validMusicXML.write(to: inDir.appendingPathComponent("song.musicxml"))

    let viewModel = AppViewModel(configFileURL: base.appendingPathComponent("config.json"),
                                 defaultFolder: folder)
    await viewModel.run()

    #expect(viewModel.isRunning == false)
    #expect(viewModel.runResult?.status == .done)
    #expect(viewModel.runResult?.outputFilenameToDisplay == "song.txt")
}

@Test @MainActor func runRescansAfterwardSoNewOutputIsReflected() async throws {
    let base = tempDirectory()
    defer { try? FileManager.default.removeItem(at: base) }
    let folder = base.appendingPathComponent("Work")
    let inDir = folder.appendingPathComponent("in")
    try FileManager.default.createDirectory(at: inDir, withIntermediateDirectories: true)
    try validMusicXML.write(to: inDir.appendingPathComponent("song.musicxml"))

    let viewModel = AppViewModel(configFileURL: base.appendingPathComponent("config.json"),
                                 defaultFolder: folder)
    await viewModel.run()

    // The input file is still there afterward (Run never deletes input), so the
    // rescan should still show it.
    #expect(viewModel.scanned.map(\.name) == ["song.musicxml"])
}

@Test @MainActor func concurrentRunCallsLeaveConsistentFinalState() async throws {
    // DESKTOP-SPEC.md §6: no second Run may start mid-run. Firing two run()
    // calls concurrently must never crash, corrupt state, or leave isRunning
    // stuck true — whichever one's guard lets through must finish cleanly.
    let base = tempDirectory()
    defer { try? FileManager.default.removeItem(at: base) }
    let folder = base.appendingPathComponent("Work")
    let inDir = folder.appendingPathComponent("in")
    try FileManager.default.createDirectory(at: inDir, withIntermediateDirectories: true)
    try validMusicXML.write(to: inDir.appendingPathComponent("song.musicxml"))

    let viewModel = AppViewModel(configFileURL: base.appendingPathComponent("config.json"),
                                 defaultFolder: folder)

    async let first: Void = viewModel.run()
    async let second: Void = viewModel.run()
    _ = await (first, second)

    #expect(viewModel.isRunning == false)
    #expect(viewModel.runResult != nil)
}
