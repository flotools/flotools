import CoreGraphics
import FloSystem

/// Pro Tools window-level facts and actions that belong to no one window model: floating windows, table frames and the Edit window's clip list.
extension ProToolsApp {
    /// Closes every window except the Mix and Edit windows by pressing its close button, as Close All Floating Windows did, and returns how many it closed. A window without a close button, such as a dialog, is left open; the JXA failed there.
    @AccessibilityActor
    public func closeFloatingWindows() throws -> Int {
        let app = AXElement.application(pid: pid)
        var closed = 0
        for window in try app.windows {
            let title = try window.title ?? ""
            guard !title.contains("Mix:"), !title.contains("Edit:"), let close = try window.element("AXCloseButton") else { continue }
            try close.press()
            closed += 1
        }
        Log.info(.accessibility, "closed \(closed) floating window(s)")
        return closed
    }

    /// Where the table is on screen, for macros that put the mouse on its edge.
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
            let front = try AXElement.application(pid: pid).required("the front window") { try $0.focusedWindow }
            element = try front.required("the Track List table") { try $0.table("Track List") }
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
        try window(titlePrefix: "Edit:", "the Edit window").required("the clip list") { try $0.table("clip list") }
    }

    /// The first quoted part of a clip element's name, quotes included, like the JXA's `/(\".*?\")/`.
    nonisolated static func quotedClipName(_ name: String) -> String? {
        guard let open = name.firstIndex(of: "\""), let close = name[name.index(after: open)...].firstIndex(of: "\"") else { return nil }
        return String(name[open...close])
    }
}
