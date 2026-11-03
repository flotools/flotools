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
            guard !ProToolsWindowKind(title: title).isTrackWindow, let close = try window.closeButton else { continue }
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
            element = try TrackList.table(in: frontWindow(), requiredAs: "the Track List table")
        }
        return try element.requiredFrame(of: "the table")
    }

    /// The names of the clips selected in the Edit window's clip list, quoted as Pro Tools shows them, for example "\"Kick_01\"".
    @AccessibilityActor
    public func selectedClipNames() throws -> [String] {
        try clipRows().filter { try $0.row.bool("AXSelected") == true }.compactMap { try $0.label.name.flatMap(Self.quotedClipName) }
    }

    /// The Edit window as an identity, to tell whether something found in it belongs to the session open now. This assumes Pro Tools gives each session its own Edit window element and keeps it while the session is open, so a mark from a closed session does not match the next one, even one with the same name. Not yet checked live (2026-11-03).
    @AccessibilityActor
    public struct EditWindowIdentity {
        private let window: AXElement

        init(_ window: AXElement) { self.window = window }

        public func isSame(as other: EditWindowIdentity) -> Bool { window.isSame(as: other.window) }
    }

    @AccessibilityActor
    public func editWindowIdentity() throws -> EditWindowIdentity { EditWindowIdentity(try trackWindow(.edit)) }

    /// A clip as the clip list shows it now. Pro Tools exposes clips only as clip list rows, not on the timeline, and only the rows scrolled into view (checked live 2026-11-03).
    public struct ListedClip: Sendable, Equatable {
        /// The row's text without the "Selected. " that Pro Tools puts before a selected clip, for example `Audio Clip "Guitar_01"  Timebase selector (samples)`, so it stays the same when the selection changes.
        public let name: String
        /// Where the row's text is on screen.
        public let frame: CGRect
    }

    /// The clip whose row is at `point`, nil when no clip row in view is there. The whole row counts, because the VoiceOver cursor may be on the row's empty first cell or on the cell around the text, which is a point wider than the text (checked live 2026-11-03).
    @AccessibilityActor
    public func listedClip(at point: CGPoint) throws -> ListedClip? {
        for entry in try clipRows() {
            guard let frame = try entry.row.frame, frame.contains(point) else { continue }
            return try listedClip(entry.label)
        }
        return nil
    }

    /// The clip named `name` where its row is now, nil when it is not in view, for example after the list scrolled.
    @AccessibilityActor
    public func listedClip(named name: String) throws -> ListedClip? {
        try listedClips().first { $0.name == name }
    }

    @AccessibilityActor
    private func listedClips() throws -> [ListedClip] {
        try clipRows().compactMap { try listedClip($0.label) }
    }

    @AccessibilityActor
    private func listedClip(_ label: AXElement) throws -> ListedClip? {
        guard let text = try label.name, let frame = try label.frame else { return nil }
        return ListedClip(name: Self.clipName(rowText: text), frame: frame)
    }

    /// The clip list's rows with the element that holds each row's text. A clip row's second cell holds one element whose name is like `Audio Clip "Kick_01" ...`; rows without it are left out.
    @AccessibilityActor
    private func clipRows() throws -> [(row: AXElement, label: AXElement)] {
        try clipList().rows.compactMap { row in
            let cells = try row.children
            guard let label = try secondCellContent(of: cells) else { return nil }
            return (row, label)
        }
    }

    /// "Selected. Audio Clip \"Kick_01\" ..." -> "Audio Clip \"Kick_01\" ...".
    nonisolated static func clipName(rowText: String) -> String {
        rowText.hasPrefix(selectedRowPrefix) ? String(rowText.dropFirst(selectedRowPrefix.count)) : rowText
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
