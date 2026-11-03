import Foundation
import Testing
@testable import FloEngine
@testable import FloFeatures
@testable import FloProTools
@testable import FloSystem

/// `COMMANDS.md`, the user's list of commands, is generated from the command declarations: each command's keys, windows and summary. The test fails when the file is out of date; `FLO_WRITE_BASELINES=1 swift test --filter CommandReferenceTests` writes it again.
@MainActor @Suite struct CommandReferenceTests {
    static let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("COMMANDS.md")

    @Test func everyCommandHasASummary() {
        let missing = FloFeatures.all().filter { $0.summary.isEmpty || !$0.summary.hasSuffix(".") }.map(\.id.description)
        #expect(missing.isEmpty, "Commands without a summary that ends in a period: \(missing)")
    }

    @Test func commandsFileIsUpToDate() throws {
        let text = Self.reference(FloFeatures.sections())
        if ProcessInfo.processInfo.environment["FLO_WRITE_BASELINES"] == "1" {
            try text.write(to: Self.file, atomically: true, encoding: .utf8)
            return
        }
        let current = try String(contentsOf: Self.file, encoding: .utf8)
        #expect(current == text, "COMMANDS.md is out of date. Run FLO_WRITE_BASELINES=1 swift test --filter CommandReferenceTests and read the diff.")
    }

    // MARK: Writing the file

    static func reference(_ sections: [(title: String, commands: [Command])]) -> String {
        var lines = [
            "# Flo Tools commands",
            "",
            "Generated from the command declarations in `Sources/FloFeatures/` by `CommandReferenceTests`. Do not edit it by hand: change a command's summary in its declaration and run `FLO_WRITE_BASELINES=1 swift test --filter CommandReferenceTests`.",
            "",
            "Every key works only while Pro Tools is in front, and only in the windows listed for it. Inspector keys work on the track under the VoiceOver cursor while the Inspector is on (`/`). A double press is two presses of the key within the double-press timeout set in Flo Tools preferences.",
        ]
        for section in sections {
            lines += ["", "## \(section.title)", "", "| Keys | Command | Windows | What it does |", "| --- | --- | --- | --- |"]
            lines += section.commands.map { command in
                "| \(keys(command)) | \(command.name) | \(windows(command)) | \(command.summary) |"
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// The keys as code spans; a held key once, as "(hold)", and a status menu item as words.
    static func keys(_ command: Command) -> String {
        var parts: [String] = []
        for trigger in command.triggers {
            switch trigger {
            case .hotKey(let combo, .pressed):
                let held = command.triggers.contains(.hotKey(combo, .released))
                parts.append(code("\(combo)") + (held ? " (hold)" : ""))
            case .hotKey(_, .released):
                break
            case .statusMenu:
                parts.append("Flo Tools menu")
            }
        }
        return parts.joined(separator: ", ")
    }

    /// A code span that also holds a backtick.
    static func code(_ text: String) -> String {
        text.contains("`") ? "`` \(text) ``" : "`\(text)`"
    }

    static func windows(_ command: Command) -> String {
        let scope = switch command.scope {
        case .anyProToolsWindow: "Any"
        case .windows(let kinds): KeymapTests.kindOrder.filter(kinds.contains).map(windowName).joined(separator: ", ")
        }
        return switch command.mode {
        case .any: scope
        case .inspectorOn: scope + ", Inspector on"
        case .inspectorOff: scope + ", Inspector off"
        }
    }

    static func windowName(_ kind: ProToolsWindowKind) -> String {
        switch kind {
        case .tabbedSetup: "Preferences, I/O Setup and other tabbed windows"
        case .plugIn: "Plug-in"
        default: kind.description
        }
    }
}
