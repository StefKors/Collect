// swift-tools-version: 5.9
import PackageDescription

/// SwiftUI implementation of the Collect overlay behaviors: a transparent
/// full-screen panel, element hit-testing via AXSwift, and window-geometry
/// tracking via SkyLight so the drawn rectangles follow foreign windows live.
let package = Package(
    name: "CollectUI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CollectUI", targets: ["CollectUI"]),
    ],
    dependencies: [
        .package(path: "../SkyLight"),
        .package(path: "../AXSwift"),
    ],
    targets: [
        .target(name: "CollectUI", dependencies: ["SkyLight", "AXSwift"]),
    ]
)
