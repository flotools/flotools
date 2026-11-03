import FloSystem

/// The Mix window's Track List table: one row per track, hidden ones included. Each row has two buttons: the first shows or hides the track ("Shown. Kick", "Hidden. Kick"), the second selects or deselects it ("Selected. Kick - Audio Track ", "Kick - Audio Track "). Pressing either toggles only that track (checked live 2026-11-02).
@AccessibilityActor
public struct TrackList {
    private let element: AXElement

    init(_ element: AXElement) { self.element = element }

    @AccessibilityActor
    public struct Row {
        /// The track's name as its strip is named, for example "Drums - Routing Folder Track ".
        public nonisolated let name: String
        public nonisolated let isSelected: Bool
        public nonisolated let isShown: Bool
        private let showButton: AXElement
        private let selectButton: AXElement

        init(name: String, isSelected: Bool, isShown: Bool, showButton: AXElement, selectButton: AXElement) {
            self.name = name
            self.isSelected = isSelected
            self.isShown = isShown
            self.showButton = showButton
            self.selectButton = selectButton
        }

        public func toggleShown() throws { try showButton.press() }
        public func toggleSelected() throws { try selectButton.press() }
    }

    /// All rows in list order. A row without its two buttons, which a collapsed Track List may have, is an error, so a partial list is never spoken as the whole.
    public func rows() throws -> [Row] {
        try element.rows.map { row in
            let cells = try row.children
            guard cells.count > 1, let show = try cells[0].buttons.first, let select = try cells[1].buttons.first else {
                throw FloError.notFound("the buttons of a Track List row")
            }
            let selectName = try select.name ?? ""
            return Row(name: Self.trackName(selectButtonName: selectName),
                       isSelected: Self.isSelected(selectButtonName: selectName),
                       isShown: try show.name?.hasPrefix("Shown") == true,
                       showButton: show, selectButton: select)
        }
    }

    /// "Selected. Open. Drums - Routing Folder Track " -> "Drums - Routing Folder Track ". Folder rows say whether the folder is open or closed.
    nonisolated static func trackName(selectButtonName name: String) -> String {
        var name = Substring(name)
        for prefix in ["Selected. ", "Open. ", "Closed. "] where name.hasPrefix(prefix) {
            name = name.dropFirst(prefix.count)
        }
        return String(name)
    }

    nonisolated static func isSelected(selectButtonName name: String) -> Bool {
        name.hasPrefix("Selected. ")
    }
}
