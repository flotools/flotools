import FloEngine
import FloProTools
import FloSystem

/// All macros. Each file declares the macros of one area.
public enum FloMacros {
    @MainActor
    public static var all: [Macro] {
        Inspector.macros + InspectorMode.macros + TrackStatus.macros
    }

    /// Applies what the preferences control in the engine. Called at launch and on Reload Preferences.
    @MainActor
    public static func apply(_ preferences: Preferences, to engine: MacroEngine) {
        InspectorMode.apply(preferences, to: engine)
    }

    /// Sets the start state that the KM version set on Pro Tools launch. Called when Flo Tools starts and when Pro Tools launches.
    @MainActor
    public static func setStartState(_ preferences: Preferences, in engine: MacroEngine) {
        InspectorMode.applyStartState(preferences, to: engine)
    }

    /// Called for every app launch; acts only on Pro Tools.
    @MainActor
    public static func applicationLaunched(bundleID: String?, in engine: MacroEngine) {
        guard bundleID == ProTools.bundleID else { return }
        setStartState(Preferences.load(), in: engine)
    }

    /// An engine with all groups and macros installed.
    @MainActor
    public static func makeEngine() -> MacroEngine {
        makeEngine(macros: all)
    }

    /// An engine with all groups and the given macros, for tests.
    @MainActor
    static func makeEngine(macros: [Macro]) -> MacroEngine {
        let engine = MacroEngine(groups: groups, hotKeys: HotKeyCenter(), contextMonitor: ContextMonitor())
        macros.forEach(engine.install)
        return engine
    }
}
