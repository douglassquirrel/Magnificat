import SwiftUI
import MagnificatDesktopCore

/// The real locations `DESKTOP-SPEC.md` §5 specifies. Kept out of
/// `AppViewModel`'s initializer defaults on purpose — every test injects its
/// own temp URLs instead, so nothing here is exercised except by actually
/// running the app.
enum RealLocations {
    static var configFile: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MagnificatDesktop")
            .appendingPathComponent("config.json")
    }

    static var defaultFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MagnificatDesktop")
    }
}

@main
struct MagnificatDesktopApp: App {
    @StateObject private var viewModel = AppViewModel(
        configFileURL: RealLocations.configFile,
        defaultFolder: RealLocations.defaultFolder)

    var body: some Scene {
        WindowGroup("Magnificat Desktop") {
            ContentView(viewModel: viewModel)
        }
        .windowResizability(.contentSize)
    }
}
