// swift-tools-version: 5.9
import PackageDescription

/// Swift wrapper around the private SkyLight framework (the WindowServer
/// client library). All entry points are resolved with dlopen/dlsym at
/// runtime, so nothing here links against private symbols directly.
let package = Package(
    name: "SkyLight",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SkyLight", targets: ["SkyLight"]),
    ],
    targets: [
        .target(name: "SkyLight"),
    ]
)
