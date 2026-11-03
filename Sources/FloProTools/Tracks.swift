import FloSystem

/// Track lookups shared by many macros.
@MainActor
public enum Tracks {
    /// The Mix window track strip whose name is under the VoiceOver cursor, like `mix.groups.byName(vo.voCursor.textUnderCursor())`.
    public static func underVoiceOverCursor() -> AXElement? {
        guard let mix = ProTools.mixWindow, let name = VoiceOver.cursorText() else { return nil }
        return mix.group(name)
    }
}
