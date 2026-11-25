import Foundation
import FloSystem

public enum TrackMoveDirection: Sendable { case earlier, later }

public enum TrackMoveResult: Equatable, Sendable {
    case noSelection
    case atBoundary
    case moved(count: Int, position: Int)
}

/// A native drag gathers selected tracks into one block, preserving their relative order.
struct TrackMovePlan: Equatable {
    let source: ClosedRange<Int>
    let neighbor: Int
    let expectedOrder: [Int]
    let expectedSelection: [Int]

    init?(count: Int, selected: [Int], direction: TrackMoveDirection) throws {
        guard let first = selected.first, let last = selected.last,
              first >= 0, last >= first, last < count,
              selected == selected.sorted(), Set(selected).count == selected.count else {
            throw FloError.unexpectedValue("the selected Track List row indices")
        }
        let neighbor = direction == .earlier ? first - 1 : last + 1
        guard (0..<count).contains(neighbor) else { return nil }
        self.source = first...last
        self.neighbor = neighbor
        let chosen = Set(selected)
        var order = (0..<count).filter { !chosen.contains($0) }
        let insertion = direction == .earlier ? neighbor : neighbor + 1 - selected.count
        order.insert(contentsOf: selected, at: insertion)
        self.expectedOrder = order
        self.expectedSelection = Array(insertion..<(insertion + selected.count))
    }

    /// `x` is in the name column, where a press grabs the row.
    static func dragPoints(source: Int, neighbor: Int, direction: TrackMoveDirection, rowHeight: CGFloat,
                           x: CGFloat, viewport: CGRect, offset: CGFloat) -> (start: CGPoint, end: CGPoint) {
        let sourceY = viewport.minY + CGFloat(source) * rowHeight - offset
        let neighborY = viewport.minY + CGFloat(neighbor) * rowHeight - offset
        let start = CGPoint(x: x, y: sourceY + rowHeight / 2)
        let end = CGPoint(x: start.x, y: direction == .earlier ? neighborY + 0.75 : neighborY + rowHeight - 0.75)
        return (start, end)
    }

    /// Track numbers count shown tracks, not Track List rows; hidden rows have a blank number column.
    static func name(_ label: String, numbered: Bool, shown: Bool) throws -> String {
        guard numbered else { return label }
        if !shown {
            guard label.hasPrefix(" ") else { throw FloError.unexpectedValue("the hidden track's blank number column") }
            return String(label.dropFirst())
        }
        guard let space = label.firstIndex(of: " "), let number = Int(label[..<space]), number > 0 else {
            throw FloError.unexpectedValue("the shown track's number")
        }
        return String(label[label.index(after: space)...])
    }
}

struct TrackMoveRow: Equatable {
    let name: String
    let isShown: Bool
    let folder: TrackMoveFolder?
}

enum TrackMoveFolder: Equatable { case open, closed }

struct TrackMoveState: Equatable {
    let rows: [TrackMoveRow]
    let selected: [Int]
    var names: [String] { rows.map(\.name) }
}

/// Closing a selected folder exposes it as one draggable row, including all its members.
struct TrackMoveFold: Equatable {
    let folder: TrackMoveRow
    let members: [TrackMoveRow]

    init(before: [TrackMoveRow], after: [TrackMoveRow], name: String) throws {
        guard let index = before.firstIndex(where: { $0.name == name }), before[index].folder == .open,
              after.indices.contains(index), after[index] == TrackMoveRow(name: name, isShown: before[index].isShown, folder: .closed) else {
            throw FloError.couldNot("identify the closed folder's members")
        }
        let next = after.indices.contains(index + 1) ? after[index + 1].name : nil
        let end = next.flatMap { next in before[(index + 1)...].firstIndex(where: { $0.name == next }) } ?? before.endIndex
        guard after == Array(before[..<index]) + [after[index]] + Array(before[end...]) else {
            throw FloError.couldNot("identify the closed folder's members")
        }
        folder = before[index]
        members = Array(before[(index + 1)..<end])
    }

    func expanding(_ rows: [TrackMoveRow]) -> [TrackMoveRow] {
        rows.flatMap { $0.name == folder.name ? [folder] + members : [$0] }
    }
}

extension ProToolsApp {
    @AccessibilityActor
    public func moveSelectedTracks(_ direction: TrackMoveDirection) async throws -> TrackMoveResult {
        let window = try frontWindow()
        switch try window.name.map(ProToolsWindowKind.init(title:)) {
        case .mix, .edit: break
        default: throw FloError.couldNot("move tracks outside the Mix or Edit window")
        }
        let numbered = try control(.menuItem(menu: "View", .is("Track Number"))).isOn
        return try await TrackReorder(window: window, pid: pid, numbered: numbered).move(direction)
    }
}
