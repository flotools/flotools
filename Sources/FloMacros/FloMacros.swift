import FloEngine
import FloProTools
import FloSystem

/// All macros. Each file declares the macros of one area.
public enum FloMacros {
    /// All macros. `openPreferences` shows the app's preferences panel.
    @MainActor
    public static func all(openPreferences: @escaping @MainActor @Sendable () -> Void = {}) -> [Macro] {
        Inspector.macros + InspectorMode.macros + TrackStatus.macros + PreferenceMacros.macros(openPreferences: openPreferences)
    }

    /// Applies what the preferences control, like the KM Refresh Preference macro: the double-press timeout and whether Toggle Temporary Inspector works. Called at launch and after the preferences panel saves.
    @MainActor
    public static func apply(_ preferences: Preferences, to engine: MacroEngine) {
        engine.doublePressTimeout = .milliseconds(preferences.timeout)
        InspectorMode.apply(preferences, to: engine)
    }

    /// Sets the start state that the KM version set on Pro Tools launch. Called when Flo Tools starts and when Pro Tools launches.
    @MainActor
    public static func setStartState(_ preferences: Preferences, in engine: MacroEngine) {
        InspectorMode.applyStartState(preferences, to: engine)
    }

    /// Called for every app launch; acts only on Pro Tools.
    @MainActor
    public static func applicationLaunched(bundleID: String?, preferences: Preferences, in engine: MacroEngine) {
        guard bundleID == ProToolsApp.bundleID else { return }
        setStartState(preferences, in: engine)
    }

    /// An engine with all groups and macros installed, using the app's hotkeys and context monitor.
    @MainActor
    public static func makeEngine(hotKeys: HotKeyCenter, contextMonitor: ContextMonitor, openPreferences: @escaping @MainActor @Sendable () -> Void) -> MacroEngine {
        makeEngine(macros: all(openPreferences: openPreferences), hotKeys: hotKeys, contextMonitor: contextMonitor)
    }

    /// An engine with all groups and the given macros. Tests never start it, so the default hotkeys and monitor stay unused.
    @MainActor
    static func makeEngine(macros: [Macro] = all(), hotKeys: HotKeyCenter = HotKeyCenter(), contextMonitor: ContextMonitor = ContextMonitor()) -> MacroEngine {
        let engine = MacroEngine(groups: groups, hotKeys: hotKeys, contextMonitor: contextMonitor)
        macros.forEach(engine.install)
        return engine
    }
}
