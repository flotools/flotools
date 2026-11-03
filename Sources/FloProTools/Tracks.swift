import FloSystem

/// Track lookups shared by many macros.
@MainActor
public enum Tracks {
    /// The Mix window track strip whose name is under the VoiceOver cursor, like `mix.groups.byName(vo.voCursor.textUnderCursor())`.
    public static func underVoiceOverCursor() throws -> AXElement {
        let mix = try ProTools.mixWindow.required("the Mix window")
        let name = try VoiceOver.cursorText().required("the VoiceOver cursor")
        return try mix.group(name).required("the track \(name) in the Mix window")
    }
}
