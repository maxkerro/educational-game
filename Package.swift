// swift-tools-version:5.9
import PackageDescription

// Builds with the Command Line Tools only (no Xcode, no XCTest needed):
//   swift build                  compile everything
//   swift run PagePalsChecks     run the logic checks (exit code 1 on failure)
//   ./build-app.sh               produce build/PagePals.app

let package = Package(
    name: "PagePals",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PagePalsCore", targets: ["PagePalsCore"]),
        .library(name: "PagePalsImport", targets: ["PagePalsImport"]),
        .executable(name: "PagePals", targets: ["PagePalsApp"]),
        .executable(name: "PagePalsChecks", targets: ["PagePalsChecks"])
    ],
    targets: [
        .target(name: "PagePalsCore"),
        .target(name: "PagePalsImport", dependencies: ["PagePalsCore"]),
        .executableTarget(name: "PagePalsApp", dependencies: ["PagePalsCore", "PagePalsImport"]),
        .executableTarget(name: "PagePalsChecks", dependencies: ["PagePalsCore"])
    ]
)
