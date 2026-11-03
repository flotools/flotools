import CoreGraphics
import FloSystem

/// Pro Tools window-level facts and actions that belong to no one window model: floating windows, table frames and the Edit window's clip list.
extension ProToolsApp {
    /// Closes every window except the Mix and Edit windows by pressing its close button, as Close All Floating Windows did. It does not wait to see them close: in one live check (J-113) Pro Tools ignored the press. A window without a close button, such as a dialog, is left open; the JXA failed there. Mix and Edit are told apart by `ProToolsWindowKind`, as for key routing; the JXA kept any title containing "Mix:" or "Edit:", so a plug-in window such as "Plug-in: Mix: Bus" stayed open.
    @AccessibilityActor
    public func closeFloatingWindows() throws {
        let app = AXElement.application(pid: pid)
        var pressed = 0
        for window in try app.windows {
            let title = try window.title ?? ""
            guard !ProToolsWindowKind(title: title).isTrackWindow, let close = try window.element("AXCloseButton") else { continue }
            try close.press()
            pressed += 1
        }
        Log.info(.accessibility, "pressed the close button of \(pressed) floating window(s)")
    }

    /// Where the table is on screen, for commands that put the mouse on its edge.
    public enum Table: Sendable {
        /// The Edit window's clip list.
        case editClips
        /// The Track List table of the front window, the Mix or Edit window.
        case frontTrackList
    }

    @AccessibilityActor
    public func frame(of table: Table) throws -> CGRect {
        let element: AXElement
        switch table {
        case .editClips:
            element = try clipList()
        case .frontTrackList:
            element = try frontWindow().required("the Track List table") { try $0.table("Track List") }
        }
        let origin = try element.position.required("the position of the table")
        let size = try element.size.required("the size of the table")
        return CGRect(origin: origin, size: size)
    }

    /// The names of the clips selected in the Edit window's clip list, quoted as Pro Tools shows them, for example "\"Kick_01\"". A clip row's second cell holds one element whose name is like `Audio clip "Kick_01" ...`.
    @AccessibilityActor
    public func selectedClipNames() throws -> [String] {
        return try clipList().rows.filter { try $0.bool("AXSelected") == true }.compactMap { row in
            let cells = try row.children
            guard cells.count > 1, let name = try cells[1].children.first?.name else { return nil }
            return Self.quotedClipName(name)
        }
    }

    /// The Edit window's clip list. The KM Resize Clips Table looked for a table named "Clips", which Pro Tools no longer has (checked live 2026-11-02); its Speak Selected Clips used "clip list".
    @AccessibilityActor
    private func clipList() throws -> AXElement {
        try trackWindow(.edit).required("the clip list") { try $0.table("clip list") }
    }

    /// The first quoted part of a clip element's name, quotes included, like the JXA's `/(\".*?\")/`.
    nonisolated static func quotedClipName(_ name: String) -> String? {
        guard let open = name.firstIndex(of: "\""), let close = name[name.index(after: open)...].firstIndex(of: "\"") else { return nil }
        return String(name[open...close])
    }
}
