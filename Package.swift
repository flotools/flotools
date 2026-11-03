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
        // Command model and runtime: commands, scopes and the Inspector mode, triggers, front context, double press, preferences.
        .target(name: "FloEngine", dependencies: ["FloSystem", "FloProTools"]),
        // Pro Tools knowledge: windows, track strips.
        .target(name: "FloProTools", dependencies: ["FloSystem"]),
        // The commands, one folder per feature.
        .target(name: "FloFeatures", dependencies: ["FloSystem", "FloEngine", "FloProTools"]),
        // Menu bar app.
        .executableTarget(name: "FloTools", dependencies: ["FloSystem", "FloEngine", "FloProTools", "FloFeatures"]),
        .testTarget(name: "FloToolsTests", dependencies: ["FloSystem", "FloEngine", "FloProTools", "FloFeatures"]),
    ]
)
