import Foundation
import Combine
import MagnificatDesktopCore

/// The window's only source of truth. Every real decision — resolving the
/// configured folder, validating a folder change, guarding against a second Run
/// starting mid-run — lives here, tested directly. `ContentView` renders what
/// this exposes and nothing more.
///
/// `ObservableObject`/`@Published`, not the newer `@Observable` macro: the
/// package's platform floor is macOS 13 (shared with the portable library,
/// which must not be raised for this app's convenience), and `@Observable`
/// needs macOS 14.
@MainActor
public final class AppViewModel: ObservableObject {
    @Published public private(set) var folderText: String
    @Published public private(set) var scanned: [ScannedFile] = []
    @Published public private(set) var isRunning = false
    @Published public private(set) var runResult: RunResult?
    @Published public private(set) var folderErrorMessage: String?

    private let configFileURL: URL
    private var currentFolder: URL
    private let runner: Runner

    public init(configFileURL: URL, defaultFolder: URL, runner: Runner = Runner()) {
        self.configFileURL = configFileURL
        self.runner = runner
        let config = (try? ConfigurationStore.load(from: configFileURL, defaultFolder: defaultFolder))
            ?? DesktopConfiguration(folder: defaultFolder)
        self.currentFolder = config.folder
        self.folderText = config.folder.path
        rescan()
    }

    /// False only while a run is in progress — there is no cancel, and no
    /// second Run may start mid-run. `DESKTOP-SPEC.md` §6.
    public var canRun: Bool { !isRunning }

    /// Re-reads `currentFolder/in` and updates `scanned`. Never throws to the
    /// caller — a listing failure just leaves `scanned` at its previous value,
    /// since the window has no dialog to report it through and the next
    /// successful scan or Run supersedes it anyway.
    public func rescan() {
        try? ConfigurationStore.ensureFolders(for: DesktopConfiguration(folder: currentFolder))
        if let files = try? scanInputFolder(currentFolder.appendingPathComponent("in")) {
            scanned = files
        }
    }

    /// Validates, persists, and switches to a new folder — the in-window
    /// alternative to a picker. Never a dialog: failure is reported through
    /// `folderErrorMessage`, exactly like a run's failure is reported through
    /// `runResult`. `DESKTOP-SPEC.md` §5.
    public func useFolder(_ path: String) {
        let url = URL(fileURLWithPath: path)
        let config = DesktopConfiguration(folder: url)
        do {
            try ConfigurationStore.ensureFolders(for: config)
            try ConfigurationStore.save(config, to: configFileURL)
            currentFolder = url
            folderText = url.path
            folderErrorMessage = nil
            rescan()
        } catch {
            folderErrorMessage = String(describing: error)
        }
    }

    // MARK: - Display composition

    /// `"RUNNING"`, or the completed run's headline, or `"IDLE"` before any run
    /// has happened. Composed here — not in the View — after a live check found
    /// idle-state text leaking into a completed run's display; see
    /// `displayDetail` for the actual bug.
    public var displayHeadline: String {
        if isRunning { return "RUNNING" }
        return runResult?.headline ?? "IDLE"
    }

    /// The one-line detail beneath the headline, or `nil` when nothing more
    /// needs saying.
    ///
    /// **Once a run has happened, this never falls back to the idle folder
    /// listing** — even when the run's own `detail` is `nil`. Run leaves input
    /// files in place and rescans afterward, so `scanned` still shows them; a
    /// naive `runResult?.detail ?? idleDetail(...)` showed "1 file ready in
    /// FOLDER/in" underneath a "DONE" headline, which reads as if the run left
    /// something unprocessed. Found by actually running the app, not by a unit
    /// test — this composition previously lived only in the untested View.
    public var displayDetail: String? {
        if isRunning { return nil }
        if let runResult { return runResult.detail }
        return idleDetail(scanned: scanned)
    }

    /// The output filename, shown big, only for a single-file run — `nil`
    /// while running or before any run.
    public var displayOutputFilename: String? {
        guard !isRunning else { return nil }
        return runResult?.outputFilenameToDisplay
    }

    /// The file-list lines to show: the run's own capped list once one exists,
    /// the idle folder listing before that, nothing while running.
    public var displayFileLines: [String] {
        guard !isRunning else { return [] }
        if let runResult { return runResult.visibleFileLines }
        return idleVisibleLines(scanned: scanned)
    }

    /// Runs once over the current folder, off the main actor so a larger batch
    /// never blocks the window, then rescans so newly written output — and any
    /// input files an operator dropped in mid-run — are reflected.
    public func run() async {
        guard canRun else { return }
        isRunning = true
        let folder = currentFolder
        let runner = self.runner
        let result = await Task.detached { runner.run(folder: folder) }.value
        runResult = result
        isRunning = false
        rescan()
    }
}
