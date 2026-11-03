import Foundation
import Testing
@testable import FloEngine
@testable import FloFeatures
@testable import FloProTools
@testable import FloSystem

/// The keymap baseline: every binding, and which command each contested key runs in each window and Inspector state. Both are compared with text files in `Tests/Baselines/`, so any change to keys, scopes, defaults or precedence shows up as a diff there. A change on purpose is made by running the tests with `FLO_WRITE_BASELINES=1` and committing the new files with the reason.
///
/// The descriptions use the app's vocabulary (scope, mode, command), not how the engine stores it, so the files stay the same while the engine changes shape.
@MainActor @Suite struct KeymapTests {
    static let baselines = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Baselines")
    static let proTools = ProToolsApp.bundleID

    /// Windows to route in: one of each kind, the unknown title while it is read, titles near the rules' edges, and another app.
    static let contexts: [(label: String, context: FrontContext)] = [
        ("Finder", FrontContext(bundleID: "com.apple.finder", windowTitle: "Mix: S")),
        ("unknown", FrontContext(bundleID: proTools, windowTitle: nil)),
        ("Mix: S", FrontContext(bundleID: proTools, windowTitle: "Mix: S")),
        ("Edit: S", FrontContext(bundleID: proTools, windowTitle: "Edit: S")),
        ("Edit: Preferences", FrontContext(bundleID: proTools, windowTitle: "Edit: Preferences")),
        ("Untitled Edit: S", FrontContext(bundleID: proTools, windowTitle: "Untitled Edit: S")),
        ("Plug-in: EQ3", FrontContext(bundleID: proTools, windowTitle: "Plug-in: EQ3")),
        ("Plug-in: Audio Suite: X", FrontContext(bundleID: proTools, windowTitle: "Plug-in: Audio Suite: X")),
        ("Mix: Audio Suite: odd", FrontContext(bundleID: proTools, windowTitle: "Mix: Audio Suite: odd")),
        ("Audio Suite: Reverb", FrontContext(bundleID: proTools, windowTitle: "Audio Suite: Reverb")),
        ("Fade In", FrontContext(bundleID: proTools, windowTitle: "Fade In")),
        ("Fade Out", FrontContext(bundleID: proTools, windowTitle: "Fade Out")),
        ("Crossfade", FrontContext(bundleID: proTools, windowTitle: "Crossfade")),
        ("Batch Fades", FrontContext(bundleID: proTools, windowTitle: "Batch Fades")),
        ("I/O Setup", FrontContext(bundleID: proTools, windowTitle: "I/O Setup")),
        ("Preferences", FrontContext(bundleID: proTools, windowTitle: "Preferences")),
        ("Peripherals", FrontContext(bundleID: proTools, windowTitle: "Peripherals")),
        ("Dashboard", FrontContext(bundleID: proTools, windowTitle: "Dashboard")),
        ("Memory Locations", FrontContext(bundleID: proTools, windowTitle: "Memory Locations")),
    ]

    @Test func keymapMatchesBaseline() throws {
        try Self.compare(Self.bindingLines(FloFeatures.makeEngine()), with: "Keymap.txt")
    }

    @Test func routingMatchesBaseline() throws {
        var lines: [String] = []
        for state in Self.inspectorStates {
            let engine = FloFeatures.makeEngine()
            Self.prepare(engine, state)
            for (combo, phase) in Self.contestedKeys(engine) {
                var winners: [String: [String]] = [:]
                for (label, context) in Self.contexts {
                    let winner = engine.candidates(for: combo, phase: phase, in: context).first?.id.description ?? "pass"
                    winners[winner, default: []].append(label)
                }
                let columns = winners.keys.sorted { ($0 == "pass" ? 1 : 0, $0) < ($1 == "pass" ? 1 : 0, $1) }.map { "\($0): \(winners[$0]!.joined(separator: ", "))" }
                lines.append("\(state) | \(Self.keyText(combo, phase)) | " + columns.joined(separator: " | "))
            }
        }
        try Self.compare(lines, with: "Routing.txt")
    }

    // MARK: Describing today's engine

    /// Inspector states to route in. Each starts from launch with "starts with Flo Tools inspector" off and "temporary inspector" on.
    static let inspectorStates = ["launch, Inspector off", "Inspector on by /", "Inspector off by /", "backtick held"]

    static func prepare(_ engine: Engine, _ state: String) {
        var preferences = Preferences()
        preferences.startsWithInspector = false
        preferences.temporaryInspector = true
        FloFeatures.apply(preferences, to: engine)
        InspectorMode.applyStartState(preferences, to: engine)
        switch state {
        case "Inspector on by /":
            engine.setInspector(true)
        case "Inspector off by /":
            engine.setInspector(true)
            engine.setInspector(false)
        case "backtick held":
            engine.dispatch(KeyCombo("`")!, .pressed, in: FrontContext(bundleID: proTools, windowTitle: "Mix: S"))
        default:
            break
        }
    }

    /// Keys bound by more than one command, and the keys that change the Inspector.
    static func contestedKeys(_ engine: Engine) -> [(KeyCombo, KeyPhase)] {
        var count: [String: (key: (KeyCombo, KeyPhase), commands: Int)] = [:]
        for command in engine.commands {
            for (combo, phase) in command.hotKeys {
                let text = keyText(combo, phase)
                count[text] = ((combo, phase), (count[text]?.commands ?? 0) + 1)
            }
        }
        // Also keys whose windows changed on purpose: the Inspector keys, and the AudioSuite buttons, which KM also took in Mix and plug-in windows with "Audio Suite:" in the title.
        let watched: Set<String> = ["/", "`", "` released", "S", "Ctrl+Opt+Shift+Cmd+B", "Ctrl+Opt+Shift+Cmd+N", "Ctrl+Opt+Shift+Cmd+P", "Ctrl+Opt+Shift+Cmd+R"]
        return count.filter { $0.value.commands > 1 || watched.contains($0.key) }.sorted { $0.key < $1.key }.map(\.value.key)
    }

    static func bindingLines(_ engine: Engine) -> [String] {
        engine.commands.flatMap { command -> [String] in
            let rest = "\(scope(command.scope)) | \(mode(command.mode)) | \(command.id) | \(action(command.action)) | \"\(command.name)\"" + (command.enabledByDefault ? "" : " | off by default")
            let triggers = command.triggers.map { trigger in
                switch trigger {
                case .hotKey(let combo, let phase): keyText(combo, phase)
                case .statusMenu: "status menu"
                }
            }
            return (triggers.isEmpty ? ["no key"] : triggers).map { "\($0) | \(rest)" }
        }.sorted()
    }

    static func keyText(_ combo: KeyCombo, _ phase: KeyPhase) -> String {
        phase == .released ? "\(combo) released" : "\(combo)"
    }

    /// Window kinds in a fixed order, so a scope reads the same every run.
    static let kindOrder: [ProToolsWindowKind] = [.mix, .edit, .plugIn, .audioSuite, .fade(.fadeIn), .fade(.fadeOut), .fade(.crossfade), .fade(.batchFades), .tabbedSetup, .keyboardShortcuts, .other]

    static func scope(_ scope: Scope) -> String {
        switch scope {
        case .anyProToolsWindow: "any Pro Tools window"
        case .windows(let kinds): kindOrder.filter(kinds.contains).map(\.description).joined(separator: ", ")
        }
    }

    static func mode(_ mode: ModeCondition) -> String {
        switch mode {
        case .any: "-"
        case .inspectorOn: "Inspector on"
        case .inspectorOff: "Inspector off"
        }
    }

    static func action(_ action: CommandAction) -> String {
        switch action {
        case .body: "run"
        case .hold: "hold"
        case .singleOrDouble(_, _, let sound):
            switch sound {
            case .beforeDouble: "single/double, sound before double"
            case .afterDouble: "single/double, sound after double"
            case .none: "single/double, no sound"
            }
        }
    }

    // MARK: Baseline files

    static func compare(_ lines: [String], with name: String) throws {
        let url = baselines.appendingPathComponent(name)
        let text = lines.joined(separator: "\n") + "\n"
        if ProcessInfo.processInfo.environment["FLO_WRITE_BASELINES"] == "1" {
            try FileManager.default.createDirectory(at: baselines, withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
            return
        }
        let expected = try String(contentsOf: url, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false).map(String.init).dropLast()
        let missing = expected.filter { !lines.contains($0) }
        let added = lines.filter { !expected.contains($0) }
        #expect(missing.isEmpty && added.isEmpty, "\(name) differs.\nMissing:\n\(missing.prefix(20).joined(separator: "\n"))\nAdded:\n\(added.prefix(20).joined(separator: "\n"))")
        #expect(Array(expected) == lines, "\(name) is in another order")
    }
}
