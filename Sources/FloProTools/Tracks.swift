import FloSystem

/// Track lookups shared by many macros.
public enum Tracks {
    /// The Mix window track strip whose name is under the VoiceOver cursor, like `mix.groups.byName(vo.voCursor.textUnderCursor())`.
    public static func underVoiceOverCursor() async throws -> AXElement {
        let mix = try await ProTools.mixWindow()
        let name = try await VoiceOver.cursorText().required("the VoiceOver cursor")
        return try await strip(named: name, in: mix)
    }

    /// The Mix window track strip with this name, for example "Kick - Audio Track ".
    @AccessibilityActor
    public static func strip(named name: String, in mix: AXElement) throws -> AXElement {
        try mix.required("the track \(name) in the Mix window") { try $0.group(name) }
    }
}
