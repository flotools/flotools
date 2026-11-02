// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FloTools",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "FloTools", targets: ["FloTools"]),
    ],
    targets: [
        // Accessibility, VoiceOver, hotkeys, window context and the macro engine.
        .target(name: "FloToolsCore"),
        // Ported Keyboard Maestro macros.
        .target(name: "FloMacros", dependencies: ["FloToolsCore"]),
        // Menu bar app.
        .executableTarget(name: "FloTools", dependencies: ["FloToolsCore", "FloMacros"]),
        .testTarget(name: "FloToolsTests", dependencies: ["FloToolsCore", "FloMacros"]),
    ]
)
