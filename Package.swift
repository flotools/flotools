// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FloTools",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "FloTools", targets: ["FloTools"]),
    ],
    targets: [
        // Generic macOS infrastructure: Accessibility, VoiceOver, hotkeys, synthetic keys, sounds.
        .target(name: "FloSystem"),
        // Macro model and runtime: groups, macros, triggers, front context, double press, preferences.
        .target(name: "FloEngine", dependencies: ["FloSystem"]),
        // Pro Tools knowledge: windows, track strips.
        .target(name: "FloProTools", dependencies: ["FloSystem"]),
        // Ported Keyboard Maestro macros.
        .target(name: "FloMacros", dependencies: ["FloSystem", "FloEngine", "FloProTools"]),
        // Menu bar app.
        .executableTarget(name: "FloTools", dependencies: ["FloSystem", "FloEngine", "FloProTools", "FloMacros"]),
        .testTarget(name: "FloToolsTests", dependencies: ["FloSystem", "FloEngine", "FloProTools", "FloMacros"]),
    ]
)
