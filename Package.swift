// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Magnificat",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "Magnificat", targets: ["Magnificat"]),
        .executable(name: "MagnificatCLI", targets: ["MagnificatCLI"]),
        .executable(name: "MagnificatDesktop", targets: ["MagnificatDesktop"]),
    ],
    targets: [
        .target(name: "Magnificat"),
        .executableTarget(name: "MagnificatCLI", dependencies: ["Magnificat"]),
        .testTarget(
            name: "MagnificatTests",
            dependencies: ["Magnificat", "MagnificatCLI"],
            resources: [.copy("Fixtures"), .copy("Golden")]
        ),

        // DESKTOP-SPEC.md governs these three. MagnificatDesktopCore holds every
        // testable behavior; MagnificatDesktop is the thin SwiftUI shell around it,
        // deliberately excluded from Foundation-only — it is host-app code.
        .target(name: "MagnificatDesktopCore", dependencies: ["Magnificat"]),
        .executableTarget(
            name: "MagnificatDesktop",
            dependencies: ["MagnificatDesktopCore"]
        ),
        .testTarget(
            name: "MagnificatDesktopCoreTests",
            dependencies: ["MagnificatDesktopCore"]
        ),
    ]
)
