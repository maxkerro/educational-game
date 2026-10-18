// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PagePals",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PagePalsCore", targets: ["PagePalsCore"])
    ],
    targets: [
        .target(name: "PagePalsCore"),
        .testTarget(name: "PagePalsCoreTests", dependencies: ["PagePalsCore"])
    ]
)
