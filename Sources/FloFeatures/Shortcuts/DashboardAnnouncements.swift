import FloEngine
import FloProTools
import FloSystem

enum DashboardAnnouncements {
    @MainActor
    static var commands: [Command] { [
        setting("sampleRate", "Sample Rate", key: "Cmd+R", identifier: "sampleRateBox"),
        setting("bitDepth", "Bit Depth", key: "Cmd+B", identifier: "bitDepthBox"),
        setting("fileType", "File Type", key: "Cmd+F", identifier: "fileTypeBox"),
        setting("ioSettings", "I/O Settings", key: "Cmd+I", identifier: "ioSettingsBox"),
        setting("interleaved", "Interleaved", key: "Cmd+G", identifier: "interleaved"),
    ] }

    @MainActor
    private static func setting(_ id: String, _ label: String, key: String, identifier: String) -> Command {
        Command(CommandID("dashboard.\(id)"), "Announce Dashboard \(label)",
                summary: "Passes the key to Pro Tools and speaks the resulting \(label.lowercased()) in the New Session Dashboard.",
                scope: .windows([.other, .tabbedSetup]), triggers: [.key(key)]) { run in
            try await announce(run, label: label, identifier: identifier)
        }
    }

    @AccessibilityActor
    private static func announce(_ run: CommandRun, label: String, identifier: String) async throws {
        let app = try? ProToolsApp.running()
        let previousControl = try? app?.newSessionSetting(identifier: identifier)
        let before = try? previousControl.flatMap { try selection($0) }
        if let previousControl, (try? previousControl.role) == "AXPopUpButton",
           (try? previousControl.isFocused) != true {
            previousControl.requestKeyboardFocus()
        }
        try await run.passThrough()
        guard let control = try app?.newSessionSetting(identifier: identifier) else { return }

        // A newly opened Dashboard may expose the value only after processing the key.
        let after = try await ProToolsUpdate.reading(changedFrom: before, within: ProToolsUpdate.passedKeyTimeout) {
            try selection(control)
        }
        if let after {
            try await VoiceOver.say("\(label), \(after)")
        }
    }

    @AccessibilityActor
    private static func selection(_ control: AXElement) throws -> String? {
        if try control.role == "AXCheckBox" {
            guard let checked = try control.bool("AXValue") else { return nil }
            return checked ? "on" : "off"
        }
        return try control.name ?? control.value
    }
}
