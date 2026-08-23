// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Magnificat",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "Magnificat", targets: ["Magnificat"]),
        .executable(name: "MagnificatCLI", targets: ["MagnificatCLI"]),
    ],
    targets: [
        .target(name: "Magnificat"),
        .executableTarget(name: "MagnificatCLI", dependencies: ["Magnificat"]),
        .testTarget(
            name: "MagnificatTests",
            dependencies: ["Magnificat", "MagnificatCLI"],
            resources: [.copy("Fixtures"), .copy("Golden")]
        ),
    ]
)
