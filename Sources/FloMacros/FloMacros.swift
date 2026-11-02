import FloToolsCore

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

    /// An engine with all groups and macros installed.
    @MainActor
    public static func makeEngine() -> MacroEngine {
        let engine = MacroEngine(groups: groups)
        all.forEach(engine.install)
        return engine
    }
}

/// Track helpers shared by many macros.
@MainActor
enum Tracks {
    /// The Mix window track strip whose name is under the VoiceOver cursor, like `mix.groups.byName(vo.voCursor.textUnderCursor())`.
    static func underVoiceOverCursor() -> AXElement? {
        guard let mix = ProTools.mixWindow, let name = VoiceOver.cursorText() else { return nil }
        return mix.group(name)
    }
}
