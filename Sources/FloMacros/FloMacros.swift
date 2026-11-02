import FloToolsCore

/// All macros. Each file declares the macros of one area.
public enum FloMacros {
    @MainActor
    public static var all: [Macro] {
        Inspector.macros + TrackStatus.macros
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
