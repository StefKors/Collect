// swift-tools-version: 5.9
import PackageDescription

/// Improved fork of the AXSwift accessibility wrapper, plus the private
/// `_AXUIElementGetWindow` bridge that maps an AXUIElement to its CGWindowID.
let package = Package(
    name: "AXSwift",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AXSwift", targets: ["AXSwift"]),
    ],
    targets: [
        .target(name: "AXSwift"),
    ]
)
