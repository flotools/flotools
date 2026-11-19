import Foundation
import FloSystem

/// Native Track List movement, with fresh AX reads after folder changes.
@AccessibilityActor
struct TrackReorder {
    let window: AXElement
    let pid: pid_t
    let numbered: Bool

    private var table: AXElement { get throws { try TrackList.table(in: window) } }

    func move(_ direction: TrackMoveDirection) async throws -> TrackMoveResult {
        let original = try readSnapshot().state
        guard !original.selected.isEmpty else { return .noSelection }
        guard Set(original.names).count == original.names.count else {
            throw FloError.couldNot("verify track order because track names are duplicated")
        }
        let openSelected = original.selected.filter { original.rows[$0].folder == .open }.map { original.rows[$0].name }
        guard !openSelected.isEmpty else {
            return try await performMove(direction)
        }
        let selection = original.selected.map { original.rows[$0].name }
        var reopen: [String] = []
        var folds: [TrackMoveFold] = []
        do {
            for name in openSelected {
                let before = try readSnapshot().state
                // An earlier selected parent may already contain this selected nested folder.
                guard before.names.contains(name) else { continue }
                reopen.append(name)
                try await setFolder(name, to: .closed)
                folds.append(try TrackMoveFold(before: before.rows, after: readSnapshot().state.rows, name: name))
            }
            try selectTracks(selection)
            let result = try await performMove(direction)
            let moved = try readSnapshot().state
            let expectedRows = folds.reduce(moved.rows) { $1.expanding($0) }
            try await reopenFolders(reopen)
            try selectTracks(selection)
            let after = try readSnapshot().state
            guard after.rows == expectedRows, after.selected.map({ after.rows[$0].name }) == selection else {
                throw FloError.couldNot("verify the folder move; check the Track List order")
            }
            if case .moved = result, let first = after.selected.first {
                return .moved(count: selection.count, position: first + 1)
            }
            return result
        } catch {
            // Cleanup must finish even when the command was cancelled during its drag or wait.
            try await Task { @AccessibilityActor in
                try await reopenFolders(reopen)
                try selectTracks(selection)
            }.value
            throw error
        }
    }

    private func setFolder(_ name: String, to state: TrackMoveFolder) async throws {
        let snapshot = try readSnapshot()
        guard let index = snapshot.state.names.firstIndex(of: name), let current = snapshot.state.rows[index].folder else {
            throw FloError.notFound("the folder \(name)")
        }
        guard current != state else { return }
        try Task.checkCancellation()
        try requireWindow()
        try snapshot.buttons[index].showMenu()
        let menu = try await AXElement.popUpMenu(pid: pid)
        let action = state == .open ? "Open" : "Close"
        try menu.required(action) { try $0.child(role: "AXMenuItem", name: action) }.press()
        let menuOpen = try await ProToolsUpdate.reading(changedFrom: true, within: .seconds(1)) {
            AXElement.showsPopUpMenu(pid: pid)
        }
        guard !menuOpen else { throw FloError.couldNot("close the track context menu") }
        let changed = try await ProToolsUpdate.reading(changedFrom: false, within: .seconds(1)) {
            let now = try readSnapshot().state
            return now.rows.first(where: { $0.name == name })?.folder == state
        }
        guard changed else { throw FloError.couldNot("\(action.lowercased()) the folder \(name)") }
    }

    private func reopenFolders(_ names: [String]) async throws {
        for name in names {
            try await setFolder(name, to: .open)
        }
    }

    private func selectTracks(_ names: [String]) throws {
        let snapshot = try readSnapshot()
        let selected = Set(snapshot.state.selected)
        let wanted = Set(names)
        for (index, row) in snapshot.state.rows.enumerated() where selected.contains(index) != wanted.contains(row.name) {
            try snapshot.buttons[index].press()
        }
    }

    private func performMove(_ direction: TrackMoveDirection) async throws -> TrackMoveResult {
        let before = try readSnapshot()
        guard let plan = try TrackMovePlan(count: before.state.names.count, selected: before.state.selected, direction: direction) else {
            return .atBoundary
        }
        let source = direction == .earlier ? plan.source.lowerBound : plan.source.upperBound
        let points = try await dragPoints(source: source, neighbor: plan.neighbor, direction: direction,
                                         original: before.state)
        let expected = TrackMoveState(rows: plan.expectedOrder.map { before.state.rows[$0] }, selected: plan.expectedSelection)
        guard try readSnapshot().state == before.state else {
            throw FloError.couldNot("move tracks because the Track List changed")
        }
        try await dragName(from: points.start, to: points.end)
        let verified = try await ProToolsUpdate.reading(changedFrom: false, within: .seconds(1)) {
            try readSnapshot().state == expected
        }
        guard verified else { throw FloError.couldNot("verify the track move; check the Track List order") }
        return .moved(count: before.state.selected.count, position: plan.expectedSelection[0] + 1)
    }

    private func readSnapshot() throws -> (state: TrackMoveState, buttons: [AXElement]) {
        var facts: [TrackMoveRow] = []
        var selected: [Int] = []
        var buttons: [AXElement] = []
        for (index, element) in try table.rows.enumerated() {
            let row = try TrackList.row(element)
            let label = try row.selectButton.name.required("a Track List track name")
            let name = try TrackMovePlan.name(row.name, numbered: numbered, shown: row.isShown)
            let folderLabel = label.hasPrefix(selectedRowPrefix) ? String(label.dropFirst(selectedRowPrefix.count)) : label
            facts.append(TrackMoveRow(name: name, isShown: row.isShown, folder: folderLabel.hasPrefix("Open. ") ? .open : folderLabel.hasPrefix("Closed. ") ? .closed : nil))
            if row.isSelected { selected.append(index) }
            buttons.append(row.selectButton)
        }
        return (TrackMoveState(rows: facts, selected: selected), buttons)
    }

    private func restoreSelection(_ original: TrackMoveState) throws {
        let current = try readSnapshot()
        guard current.state.rows == original.rows else { throw FloError.couldNot("move tracks because the Track List changed") }
        for index in current.buttons.indices where current.state.selected.contains(index) != original.selected.contains(index) {
            try current.buttons[index].press()
        }
    }

    /// Pro Tools reports unscrolled row frames. Native hit-testing provides the actual viewport.
    private func viewport() throws -> CGRect {
        let table = try table.requiredFrame(of: "the Track List")
        let point = CGPoint(x: table.midX, y: table.minY + 2)
        guard let area = try AXElement.at(point, pid: pid), try area.role == "AXScrollArea" else {
            throw FloError.couldNot("locate the Track List viewport")
        }
        let viewport = try area.requiredFrame(of: "the Track List viewport")
        guard abs(viewport.minY - table.minY) < 2, abs(viewport.minX - table.minX) < 2, viewport.height > 30 else {
            throw FloError.couldNot("locate the Track List viewport")
        }
        return viewport
    }

    /// Select a visible row to identify it; measure a row boundary and restore the original selection.
    private func scrollOffset(viewport: CGRect, rowHeight: CGFloat, original: TrackMoveState) async throws -> CGFloat {
        do {
            let snapshot = try readSnapshot()
            guard snapshot.state == original else { throw FloError.couldNot("move tracks because the Track List changed") }
            for index in original.selected { try snapshot.buttons[index].press() }
            func row(at y: CGFloat) async throws -> Int {
                try Task.checkCancellation()
                try requireWindow()
                let previous = try selectedIndices(original: original)
                try await Mouse.click(at: CGPoint(x: viewport.midX, y: y), ifFront: pid)
                let selected = try await ProToolsUpdate.reading(changedFrom: previous, within: .milliseconds(150)) {
                    try selectedIndices(original: original)
                }
                guard selected.count == 1, let index = selected.first else { throw FloError.couldNot("identify a visible Track List row") }
                Log.debug(.accessibility, "Track List probe at y=\(y) selected row \(index)")
                return index
            }
            var low = viewport.minY + 1
            var high = low + rowHeight
            let first = try await row(at: low)
            guard try await row(at: high) == first + 1 else { throw FloError.couldNot("measure the Track List rows") }
            // A half-point bound keeps the final insertion point on the intended side of the row edge.
            while high - low > 0.5 {
                let middle = (low + high) / 2
                let index = try await row(at: middle)
                if index == first { low = middle }
                else if index == first + 1 { high = middle }
                else { throw FloError.couldNot("measure the Track List rows") }
            }
            try restoreSelection(original)
            return CGFloat(first + 1) * rowHeight + viewport.minY - (low + high) / 2
        } catch {
            try restoreSelection(original)
            throw error
        }
    }

    private func selectedIndices(original: TrackMoveState) throws -> [Int] {
        try table.elements("AXSelectedRows").compactMap { element in
            let row = try TrackList.row(element)
            guard row.isSelected else { return nil }
            let name = try TrackMovePlan.name(row.name, numbered: numbered, shown: row.isShown)
            guard let index = original.names.firstIndex(of: name) else {
                throw FloError.couldNot("move tracks because the Track List changed")
            }
            return index
        }
    }

    private func dragPoints(source: Int, neighbor: Int, direction: TrackMoveDirection, original: TrackMoveState) async throws -> (start: CGPoint, end: CGPoint) {
        let viewport = try viewport()
        let rows = try table.rows
        let height = try rows[source].requiredFrame(of: "the source Track List row").height
        guard height > 4 else { throw FloError.couldNot("measure the Track List row height") }
        for _ in 0..<8 {
            let offset = try await scrollOffset(viewport: viewport, rowHeight: height, original: original)
            let points = TrackMovePlan.dragPoints(source: source, neighbor: neighbor, direction: direction,
                                                  rowHeight: height, viewport: viewport, offset: offset)
            if viewport.insetBy(dx: 1, dy: 0.5).contains(points.start), viewport.insetBy(dx: 1, dy: 0.5).contains(points.end) { return points }
            try Task.checkCancellation()
            try requireWindow()
            let delta = (viewport.midY - (points.start.y + points.end.y) / 2) / 3
            let pixels = Int32(max(-10000, min(10000, delta.rounded())))
            try Mouse.scroll(at: CGPoint(x: viewport.midX, y: viewport.midY), verticalPixels: pixels, ifFront: pid)
            try await Task.sleep(for: .milliseconds(100))
        }
        throw FloError.couldNot("bring the Track List drag endpoints into view")
    }

    private func requireWindow() throws {
        guard let front = try AXElement.application(pid: pid).focusedWindow, front.isSame(as: window) else {
            throw CancellationError()
        }
    }

    private func dragName(from start: CGPoint, to end: CGPoint) async throws {
        try requireWindow()
        let middle = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        try Mouse.move(to: start, ifFront: pid)
        try await Task.sleep(for: .milliseconds(150))
        try Task.checkCancellation()
        try requireWindow()
        try Mouse.pressButton(at: start, ifFront: pid)
        var release = start
        defer { Mouse.releaseButton(at: release) }
        try await Task.sleep(for: .milliseconds(150))
        for point in [middle, end, end] {
            try Task.checkCancellation()
            try requireWindow()
            try Mouse.dragButton(to: point, ifFront: pid)
            release = point
            try await Task.sleep(for: .milliseconds(150))
        }
    }
}
