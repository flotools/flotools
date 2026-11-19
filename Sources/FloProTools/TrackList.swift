import Foundation
import FloSystem

/// The Mix window's Track List table: one row per track, hidden ones included. Each row has two buttons: the first shows or hides the track ("Shown. Kick", "Hidden. Kick"), the second selects or deselects it ("Selected. Kick - Audio Track ", "Kick - Audio Track "). Pressing either toggles only that track (checked live 2026-11-02).
@AccessibilityActor
public struct TrackList {
    /// What a failure names when a row lacks its show or selection button.
    private static let rowButtons = "the buttons of a Track List row"

    private let element: AXElement

    init(_ element: AXElement) { self.element = element }

    /// The Track List table among the children of a Mix or Edit window.
    static func table(in window: AXElement) throws -> AXElement {
        try window.required("the Track List") { try $0.table("Track List") }
    }

    /// The two states a row shows and toggles.
    public enum Property: Sendable { case selected, shown }

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

        public func has(_ property: Property) -> Bool {
            switch property {
            case .selected: isSelected
            case .shown: isShown
            }
        }

        /// Presses the property's button, which toggles only this track.
        public func toggle(_ property: Property) throws {
            switch property {
            case .selected: try selectButton.press()
            case .shown: try showButton.press()
            }
        }
    }

    /// All rows in list order. A row without its two buttons, which a collapsed Track List may have, is an error, so a partial list is never spoken as the whole.
    public func rows() throws -> [Row] {
        try element.rows.map(Self.row)
    }

    /// The rows that have `property` (`on`) or not, in list order. Selected rows come from the table's own selection, which is one read rather than reads of every row (220 tracks: 0.8 ms instead of 70 ms). It matched the selection buttons live on 2026-11-08, with gaps in the selection and a hidden selected track. A row listed as selected whose button does not say so is left out.
    public func rows(_ property: Property, on: Bool) throws -> [Row] {
        guard property == .selected, on else { return try rows().filter { $0.has(property) == on } }
        return try selectedRowElements().map(Self.row).filter(\.isSelected)
    }

    /// The names of the selected tracks in list order, read from the selection buttons alone, for polls that need neither the show buttons nor the elements. The rows and buttons are found again on each call, because a playlist switch may replace them. A row without its selection button is an error, as in `rows()`.
    public func selectedNames() throws -> [String] {
        try selectedRowElements().compactMap { row in
            let selection = Self.selection(selectButtonName: try Self.selectionButton(in: row.children).name ?? "")
            return selection.isSelected ? selection.name : nil
        }
    }

    private func selectedRowElements() throws -> [AXElement] {
        try element.elements("AXSelectedRows")
    }

    private static func row(_ row: AXElement) throws -> Row {
        let cells = try row.children
        // The selection button first: its lookup checks that the row has both cells.
        let select = try selectionButton(in: cells)
        guard let show = try cells[0].buttons.first else { throw FloError.notFound(rowButtons) }
        let selection = selection(selectButtonName: try select.name ?? "")
        return Row(name: selection.name,
                   isSelected: selection.isSelected,
                   isShown: try show.name?.hasPrefix("Shown") == true,
                   showButton: show, selectButton: select)
    }

    /// The selection button of a row with `cells`, the row's children: the first button of the second cell.
    private static func selectionButton(in cells: [AXElement]) throws -> AXElement {
        guard let button = try secondCellContent(of: cells, role: "AXButton") else { throw FloError.notFound(Self.rowButtons) }
        return button
    }

    /// "Selected. Open. Drums - Routing Folder Track " -> "Drums - Routing Folder Track ". Folder rows say whether the folder is open or closed.
    nonisolated static func trackName(selectButtonName name: String) -> String {
        var name = Substring(name)
        for prefix in [selectedRowPrefix, "Open. ", "Closed. "] where name.hasPrefix(prefix) {
            name = name.dropFirst(prefix.count)
        }
        return String(name)
    }

    nonisolated static func isSelected(selectButtonName name: String) -> Bool {
        name.hasPrefix(selectedRowPrefix)
    }

    nonisolated static func selection(selectButtonName name: String) -> (name: String, isSelected: Bool) {
        (trackName(selectButtonName: name), isSelected(selectButtonName: name))
    }
}

/// The first child with `role` (any role if nil) of the second of `cells`, a table row's children, or nil when there is none. The Track List, the Group List and the clip list keep a row's name in its second cell. Callers decide what a missing one means.
@AccessibilityActor
func secondCellContent(of cells: [AXElement], role: String? = nil) throws -> AXElement? {
    guard cells.count > 1 else { return nil }
    return try role.map { try cells[1].children(role: $0).first } ?? cells[1].children.first
}

extension TrackList {
    /// Pro Tools needs intermediate drag events before it will accept a row drop.
    func moveSelected(_ direction: TrackMoveDirection, numbered: Bool, pid: pid_t, window: AXElement, layout: ProToolsApp.TrackWindow) async throws -> TrackMoveResult {
        let before = try moveSnapshot(numbered: numbered)
        guard !before.state.selected.isEmpty else { return .noSelection }
        guard !before.state.names.contains(where: { $0.contains("Folder Track") }) else {
            throw FloError.couldNot("move tracks in a Track List containing folders")
        }
        guard Set(before.state.names).count == before.state.names.count else {
            throw FloError.couldNot("verify track order because track names are duplicated")
        }
        guard let plan = try TrackMovePlan(count: before.state.names.count, selected: before.state.selected, direction: direction) else {
            return .atBoundary
        }
        let source = direction == .earlier ? plan.source.lowerBound : plan.source.upperBound
        // Track List row frames ignore its scroll offset. Native track headers do not.
        do {
            for index in [plan.neighbor, source] {
                try requireWindow(window, pid: pid)
                try before.buttons[index].showMenu()
                let menu = try await AXElement.popUpMenu(pid: pid)
                let reveal = try menu.required("Scroll Into View") { try $0.child(role: "AXMenuItem", name: "Scroll Into View") }
                try reveal.press()
                let menuOpen = try await ProToolsUpdate.reading(changedFrom: true, within: .seconds(1)) {
                    AXElement.showsPopUpMenu(pid: pid)
                }
                guard !menuOpen else { throw FloError.couldNot("close the track context menu") }
            }
        } catch {
            try restoreMoveSelection(before.state, numbered: numbered)
            throw error
        }
        try restoreMoveSelection(before.state, numbered: numbered)
        let sourceStrip = try moveStrip(for: before.buttons[source], in: window)
        let targetStrip = try moveStrip(for: before.buttons[plan.neighbor], in: window)
        let name = try sourceStrip.required("the selected track name control") {
            try $0.children.first { try $0.role == "AXPopUpButton" && $0.name?.hasPrefix("Track name\n") == true }
        }
        let from = try name.requiredFrame(of: "the selected track name")
        let target = try targetStrip.requiredFrame(of: "the adjacent track")
        let bounds = try window.requiredFrame(of: "the track window")
        let listBounds = try element.requiredFrame(of: "the Track List")
        let points = TrackMovePlan.dragPoints(name: from, neighbor: target, direction: direction, layout: layout)
        guard bounds.contains(from), bounds.contains(points.end), from.width > 2, from.height > 2,
              layout != .mix || min(points.start.x, points.end.x) > listBounds.maxX else {
            throw FloError.couldNot("bring the selected tracks and their destination into view")
        }
        let expected = TrackMoveState(names: plan.expectedOrder.map { before.state.names[$0] }, selected: plan.expectedSelection)
        // Do not drag a stale selection after the geometry reads.
        guard try moveSnapshot(numbered: numbered).state == before.state else {
            throw FloError.couldNot("move tracks because the Track List changed")
        }
        try await dragName(from: points.start, to: points.end, pid: pid, window: window)
        let verified = try await ProToolsUpdate.reading(changedFrom: false, within: .seconds(1)) {
            try moveSnapshot(numbered: numbered).state == expected
        }
        guard verified else { throw FloError.couldNot("verify the track move; check the Track List order") }
        return .moved(count: before.state.selected.count, position: plan.expectedSelection[0] + 1)
    }

    private func moveSnapshot(numbered: Bool) throws -> (state: TrackMoveState, buttons: [AXElement]) {
        let rows = try element.rows
        var names: [String] = []
        var selected: [Int] = []
        var buttons: [AXElement] = []
        for (index, row) in rows.enumerated() {
            let button = try Self.selectionButton(in: row.children)
            let label = try button.name.required("a Track List track name")
            let selection = Self.selection(selectButtonName: label)
            names.append(try TrackMovePlan.name(selection.name, at: index, numbered: numbered))
            if selection.isSelected { selected.append(index) }
            buttons.append(button)
        }
        return (TrackMoveState(names: names, selected: selected), buttons)
    }

    private func restoreMoveSelection(_ original: TrackMoveState, numbered: Bool) throws {
        let current = try moveSnapshot(numbered: numbered)
        guard current.state.names == original.names else { throw FloError.couldNot("move tracks because the Track List changed") }
        for index in current.buttons.indices where current.state.selected.contains(index) != original.selected.contains(index) {
            try current.buttons[index].press()
        }
    }

    private func moveStrip(for button: AXElement, in window: AXElement) throws -> AXElement {
        let name = try Self.trackName(selectButtonName: button.name.required("a Track List track name"))
        return try window.required("the shown track \(name)") { try $0.child(role: "AXGroup", name: name) }
    }

    private func requireWindow(_ window: AXElement, pid: pid_t) throws {
        guard let front = try AXElement.application(pid: pid).focusedWindow, front.isSame(as: window) else {
            throw CancellationError()
        }
    }

    private func dragName(from start: CGPoint, to end: CGPoint, pid: pid_t, window: AXElement) async throws {
        try requireWindow(window, pid: pid)
        let middle = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        try Mouse.move(to: start, ifFront: pid)
        try await Task.sleep(for: .milliseconds(150))
        try Task.checkCancellation()
        try requireWindow(window, pid: pid)
        try Mouse.pressButton(at: start, ifFront: pid)
        var release = start
        defer { Mouse.releaseButton(at: release) }
        try await Task.sleep(for: .milliseconds(150))
        for point in [middle, end, end] {
            try Task.checkCancellation()
            try requireWindow(window, pid: pid)
            try Mouse.dragButton(to: point, ifFront: pid)
            release = point
            try await Task.sleep(for: .milliseconds(150))
        }
    }
}
