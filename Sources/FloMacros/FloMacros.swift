import FloToolsCore

/// All ported macros. Each file registers its macros by Keyboard Maestro UID.
public enum FloMacros {
    @MainActor
    public static func registerAll(in engine: MacroEngine) {
        Inspector.register(in: engine)
        TrackStatus.register(in: engine)
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
