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
            "Every key works only while Pro Tools is in front, and only in the windows listed for it. Inspector keys work on the track whose name the VoiceOver cursor is on, in the Mix or Edit window. When the cursor is not on a track name, the key does what it does without the Inspector: another command listed for it runs, or the key goes to Pro Tools. Where a command has a tap and a hold action, holding the key down for the hold time set in Flo Tools preferences (200 ms unless changed) runs the hold action, and letting go sooner runs the tap action at once.",
        ]
        for section in sections {
            lines += ["", "## \(section.title)", "", "| Keys | Command | Windows | What it does |", "| --- | --- | --- | --- |"]
            lines += section.commands.map { command in
                "| \(keys(command)) | \(command.name) | \(windows(command)) | \(command.summary) |"
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// The keys as code spans, a key that repeats while held with "(hold to repeat)", and a status menu item as words.
    static func keys(_ command: Command) -> String {
        var parts: [String] = []
        let repeats = if case .repeating = command.action { true } else { false }
        for trigger in command.triggers {
            switch trigger {
            case .hotKey(let combo):
                parts.append(code("\(combo)") + (repeats ? " (hold to repeat)" : ""))
            case .statusMenu:
                parts.append("\(trigger)")
            }
        }
        return parts.joined(separator: ", ")
    }

    /// A code span that also holds a backtick.
    static func code(_ text: String) -> String {
        text.contains("`") ? "`` \(text) ``" : "`\(text)`"
    }

    static func windows(_ command: Command) -> String {
        switch command.scope {
        case .anyProToolsWindow: "Any"
        case .windows(let kinds): KeymapTests.ordered(kinds).map(windowName).joined(separator: ", ")
        case .trackUnderVoiceOverCursor: "Mix, Edit, on a track"
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
