import Foundation
import FloSystem

public enum TrackMoveDirection: Sendable { case earlier, later }

public enum TrackMoveResult: Equatable, Sendable {
    case noSelection
    case atBoundary
    case moved(count: Int, position: Int)
}

/// A single native drag can move an adjacent selection while preserving its order.
struct TrackMovePlan: Equatable {
    let source: ClosedRange<Int>
    let neighbor: Int
    let expectedOrder: [Int]
    let expectedSelection: [Int]

    init?(count: Int, selected: [Int], direction: TrackMoveDirection) throws {
        guard let first = selected.first, let last = selected.last,
              first >= 0, last >= first, last < count, selected == Array(first...last) else {
            throw FloError.couldNot("move nonadjacent tracks; select adjacent tracks first")
        }
        let offset = direction == .earlier ? -1 : 1
        let neighbor = direction == .earlier ? first - 1 : last + 1
        guard (0..<count).contains(neighbor) else { return nil }
        self.source = first...last
        self.neighbor = neighbor
        var order = Array(0..<count)
        order.removeSubrange(source)
        order.insert(contentsOf: selected, at: first + offset)
        self.expectedOrder = order
        self.expectedSelection = selected.map { $0 + offset }
    }

    /// Scroll Into View aligns its track at the leading edge, so reveal the earlier drag endpoint.
    var revealIndex: Int { neighbor < source.lowerBound ? neighbor : source.upperBound }

    /// The name starts the gesture; the neighboring strip boundary is the insertion point.
    static func dragPoints(name: CGRect, neighbor: CGRect, direction: TrackMoveDirection, layout: ProToolsApp.TrackWindow) -> (start: CGPoint, end: CGPoint) {
        let start = CGPoint(x: name.midX, y: name.midY)
        let end: CGPoint
        switch layout {
        case .mix:
            end = CGPoint(x: direction == .earlier ? neighbor.minX + 1 : neighbor.maxX - 1, y: start.y)
        case .edit:
            end = CGPoint(x: start.x, y: direction == .earlier ? neighbor.minY + 1 : neighbor.maxY - 1)
        }
        return (start, end)
    }

    /// Track List numbering changes after a reorder; the real name must not.
    static func name(_ label: String, at index: Int, numbered: Bool) throws -> String {
        guard numbered else { return label }
        let prefix = "\(index + 1) "
        guard label.hasPrefix(prefix) else {
            throw FloError.unexpectedValue("the Track List number at position \(index + 1)")
        }
        return String(label.dropFirst(prefix.count))
    }
}

struct TrackMoveState: Equatable {
    let names: [String]
    let selected: [Int]
}

extension ProToolsApp {
    @AccessibilityActor
    public func moveSelectedTracks(_ direction: TrackMoveDirection) async throws -> TrackMoveResult {
        let window = try frontWindow()
        let layout: TrackWindow
        switch try window.name.map(ProToolsWindowKind.init(title:)) {
        case .mix: layout = .mix
        case .edit: layout = .edit
        default: throw FloError.couldNot("move tracks outside the Mix or Edit window")
        }
        let numbered = try control(.menuItem(menu: "View", .is("Track Number"))).isOn
        return try await TrackList(TrackList.table(in: window)).moveSelected(direction, numbered: numbered, pid: pid, window: window, layout: layout)
    }
}
