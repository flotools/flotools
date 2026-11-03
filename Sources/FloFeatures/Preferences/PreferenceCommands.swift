import FloEngine

/// Commands about Flo Tools' own preferences.
enum PreferenceCommands {
    /// `openPreferences` comes from the app, which owns the preferences panel.
    @MainActor
    static func commands(openPreferences: @escaping @MainActor @Sendable () -> Void) -> [Command] { [
        Command("floTools.floToolsPreferences", "Flo Tools Preferences", summary: "Opens the Flo Tools preferences panel.", scope: .anyProToolsWindow, triggers: [.key("Ctrl+Cmd+,")]) { _ in
            await openPreferences()
        },
    ] }
}
