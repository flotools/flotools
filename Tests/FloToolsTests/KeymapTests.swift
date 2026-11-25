import Foundation
import Testing
@testable import FloEngine
@testable import FloFeatures
@testable import FloProTools
@testable import FloSystem

/// The keymap baseline: every binding, and which commands each contested key runs in each window, best first. Both are compared with text files in `Tests/Baselines/`, so any change to keys, scopes, defaults or precedence shows up as a diff there. A change on purpose is made by running the tests with `FLO_WRITE_BASELINES=1` and committing the new files with the reason.
///
/// The descriptions use the app's vocabulary (scope, command), not how the engine stores it, so the files stay the same while the engine changes shape.
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
        ("New Tracks", FrontContext(bundleID: proTools, windowTitle: "New Tracks")),
        ("Memory Locations", FrontContext(bundleID: proTools, windowTitle: "Memory Locations")),
    ]

    @Test func keymapMatchesBaseline() throws {
        try Self.compare(Self.bindingLines(FloFeatures.makeEngine()), with: "Keymap.txt")
    }

    /// A key whose first command is for the track under the VoiceOver cursor lists the next one too, which runs off a track, as "first else next".
    @Test func routingMatchesBaseline() throws {
        let engine = FloFeatures.makeEngine()
        var lines: [String] = []
        for combo in Self.contestedKeys(engine) {
            var winners: [String: [String]] = [:]
            for (label, context) in Self.contexts {
                let candidates = engine.candidates(for: combo, in: context)
                let firstTwo = candidates.first?.scope == .trackUnderVoiceOverCursor ? candidates.prefix(2) : candidates.prefix(1)
                let winner = firstTwo.isEmpty ? "pass" : firstTwo.map(\.id.description).joined(separator: " else ")
                winners[winner, default: []].append(label)
            }
            let columns = winners.keys.sorted { ($0 == "pass" ? 1 : 0, $0) < ($1 == "pass" ? 1 : 0, $1) }.map { "\($0): \(winners[$0]!.joined(separator: ", "))" }
            lines.append("\(combo) | " + columns.joined(separator: " | "))
        }
        try Self.compare(lines, with: "Routing.txt")
    }

    // MARK: Describing today's engine

    /// Keys bound by more than one command, and keys whose windows changed on purpose.
    static func contestedKeys(_ engine: Engine) -> [KeyCombo] {
        var count: [String: (combo: KeyCombo, commands: Int)] = [:]
        for command in engine.commands {
            for combo in command.hotKeys {
                count["\(combo)"] = (combo, (count["\(combo)"]?.commands ?? 0) + 1)
            }
        }
        // Watch an Inspector key, the AudioSuite keys, the New Tracks keys and the track move keys even when only one command uses them.
        let watched: Set<String> = ["Ctrl+Shift+Cmd+P", "Ctrl+Shift+Cmd+;", "Shift+Cmd+=", "Cmd+-", "Cmd+Keypad +", "Cmd+Keypad -", "Shift+Cmd+Up", "Shift+Cmd+Down", "Opt+Cmd+Up", "Opt+Cmd+Down", "S", "Ctrl+Opt+Shift+Cmd+B", "Ctrl+Opt+Shift+Cmd+N", "Ctrl+Opt+Shift+Cmd+P", "Ctrl+Opt+Shift+Cmd+R"]
        return count.filter { $0.value.commands > 1 || watched.contains($0.key) }.sorted { $0.key < $1.key }.map(\.value.combo)
    }

    static func bindingLines(_ engine: Engine) -> [String] {
        engine.commands.flatMap { command -> [String] in
            let rest = "\(scope(command.scope)) | \(command.id) | \(action(command.action)) | \"\(command.name)\""
            let triggers = command.triggers.map { trigger in
                switch trigger {
                case .hotKey(let combo): "\(combo)"
                case .statusMenu: "status menu"
                }
            }
            return (triggers.isEmpty ? ["no key"] : triggers).map { "\($0) | \(rest)" }
        }.sorted()
    }

    /// Window kinds in a fixed order, so a scope reads the same every run.
    /// The window kinds of `kinds` in the order the baselines list them. The switch has no default, so a new kind does not build until it has a place.
    static func ordered(_ kinds: Set<ProToolsWindowKind>) -> [ProToolsWindowKind] {
        func position(_ kind: ProToolsWindowKind) -> Int {
            switch kind {
            case .mix: 0
            case .edit: 1
            case .plugIn: 2
            case .audioSuite: 3
            case .fade(let fade): 4 + FadeDialog.Kind.allCases.firstIndex(of: fade)!
            case .tabbedSetup: 10
            case .keyboardShortcuts: 11
            case .newTracks: 12
            case .other: 13
            }
        }
        return kinds.sorted { position($0) < position($1) }
    }

    static func scope(_ scope: Scope) -> String {
        switch scope {
        case .anyProToolsWindow: "any Pro Tools window"
        case .windows(let kinds): ordered(kinds).map(\.description).joined(separator: ", ")
        case .trackUnderVoiceOverCursor: "track under VoiceOver cursor"
        }
    }

    static func action(_ action: CommandAction) -> String {
        switch action {
        case .body: "run"
        case .repeating: "repeats while held"
        case .tapOrHold(_, _, let sound):
            switch sound {
            case .beforeHold: "tap/hold, sound before hold"
            case .afterHold: "tap/hold, sound after hold"
            case .none: "tap/hold, no sound"
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
