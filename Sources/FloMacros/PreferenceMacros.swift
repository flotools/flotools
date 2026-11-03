import FloEngine

/// Macros about Flo Tools' own preferences.
enum PreferenceMacros {
    /// `openPreferences` comes from the app, which owns the preferences panel.
    @MainActor
    static func macros(openPreferences: @escaping @MainActor @Sendable () -> Void) -> [Macro] { [
        Macro("floTools.floToolsPreferences", "Flo Tools Preferences", scope: .anyProToolsWindow, triggers: [.key("Ctrl+Cmd+,")]) { _ in
            await openPreferences()
        },
    ] }
}
