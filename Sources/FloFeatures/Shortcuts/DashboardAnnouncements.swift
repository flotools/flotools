import FloEngine
import FloProTools
import FloSystem

/// The New Session Dashboard's own shortcuts, passed on to Pro Tools and announced because Pro Tools changes the settings silently. They work only while a setting has keyboard focus; Flo Tools leaves focus to the user.
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
            try await announce(run, identifier: identifier)
        }
    }

    @AccessibilityActor
    private static func announce(_ run: CommandRun, identifier: String) async throws {
        let app = try ProToolsApp.running()
        // The reading before the key is only for the wait, so its failure does not keep the key from Pro Tools.
        let before = try? app.newSessionSetting(identifier: identifier).flatMap { try spokenValue($0) }
        try await run.passThrough()
        guard let control = try app.newSessionSetting(identifier: identifier) else { return }

        // A newly opened Dashboard may expose the value only after processing the key.
        let after = try await ProToolsUpdate.reading(changedFrom: before, within: ProToolsUpdate.passedKeyTimeout) {
            try spokenValue(control)
        }
        Log.debug(.accessibility, "Dashboard \(identifier): before \(before ?? "none"), after \(after ?? "none")")
        if let after {
            try await VoiceOver.say(after)
        } else {
            Log.debug(.accessibility, "Dashboard \(identifier) has no value to speak:\n\(control.dump(depth: 1))")
        }
    }

    /// A pop-up's selected item, or "Interleaved checked" for the check box.
    @AccessibilityActor
    private static func spokenValue(_ control: AXElement) throws -> String? {
        guard try control.role == "AXCheckBox" else { return try control.name ?? control.value }
        guard let checked = try control.bool("AXValue") else { return nil }
        let state = checked ? "checked" : "unchecked"
        return try control.name.map { "\($0) \(state)" } ?? state
    }
}
