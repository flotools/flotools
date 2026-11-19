import Foundation
import Testing
import FloSystem
@testable import FloProTools
@testable import FloFeatures

@Suite struct TrackMovementTests {
    @Test func adjacentBlockMovesOnePositionAndRetainsItsOrder() throws {
        let up = try #require(try TrackMovePlan(count: 5, selected: [1, 2], direction: .earlier))
        #expect(up.expectedOrder == [1, 2, 0, 3, 4])
        #expect(up.expectedSelection == [0, 1])
        #expect(up.neighbor == 0)
        let down = try #require(try TrackMovePlan(count: 5, selected: [1, 2], direction: .later))
        #expect(down.expectedOrder == [0, 3, 1, 2, 4])
        #expect(down.expectedSelection == [2, 3])
        #expect(down.neighbor == 3)
    }

    @Test func movementAndItsReverseRestoreOrder() throws {
        for count in 2...8 {
            for first in 1..<count {
                for last in first..<count {
                    let selected = Array(first...last)
                    let up = try #require(try TrackMovePlan(count: count, selected: selected, direction: .earlier))
                    let back = try #require(try TrackMovePlan(count: count, selected: up.expectedSelection, direction: .later))
                    #expect(back.expectedOrder.map { up.expectedOrder[$0] } == Array(0..<count))
                }
            }
        }
    }

    @Test func boundariesAreNoOpsForAdjacentAndGappedSelections() throws {
        #expect(try TrackMovePlan(count: 4, selected: [0, 1], direction: .earlier) == nil)
        #expect(try TrackMovePlan(count: 4, selected: [2, 3], direction: .later) == nil)
        #expect(try TrackMovePlan(count: 4, selected: [0, 2], direction: .earlier) == nil)
        #expect(try TrackMovePlan(count: 4, selected: [1, 3], direction: .later) == nil)
    }

    @Test func nonadjacentTracksGatherBeforeOrAfterTheOuterNeighbor() throws {
        let up = try #require(try TrackMovePlan(count: 12, selected: [5, 7, 9], direction: .earlier))
        #expect(up.expectedOrder == [0, 1, 2, 3, 5, 7, 9, 4, 6, 8, 10, 11])
        #expect(up.expectedSelection == [4, 5, 6])
        let down = try #require(try TrackMovePlan(count: 12, selected: [5, 7, 9], direction: .later))
        #expect(down.expectedOrder == [0, 1, 2, 3, 4, 6, 8, 10, 5, 7, 9, 11])
        #expect(down.expectedSelection == [8, 9, 10])
    }

    @Test func gatheringPreservesEveryTrackAndBothRelativeOrders() throws {
        for count in 2...8 {
            for mask in 1..<(1 << count) {
                let selected = (0..<count).filter { mask & (1 << $0) != 0 }
                let unselected = (0..<count).filter { !selected.contains($0) }
                for direction: TrackMoveDirection in [.earlier, .later] {
                    guard let move = try TrackMovePlan(count: count, selected: selected, direction: direction) else { continue }
                    #expect(move.expectedOrder.sorted() == Array(0..<count))
                    #expect(move.expectedSelection.map { move.expectedOrder[$0] } == selected)
                    #expect(move.expectedOrder.filter { !selected.contains($0) } == unselected)
                    let first = try #require(move.expectedSelection.first)
                    #expect(move.expectedSelection == Array(first..<(first + selected.count)))
                }
            }
        }
    }

    @Test func invalidSelectionCannotConstructAnInvalidRange() {
        for selected in [[], [2, 0], [-1], [4], [1, 1]] {
            #expect(throws: FloError.unexpectedValue("the selected Track List row indices")) {
                try TrackMovePlan(count: 4, selected: selected, direction: .earlier)
            }
        }
    }

    @Test func displayedNumbersFollowVisibilityRatherThanListPosition() throws {
        #expect(try TrackMovePlan.name("3 DrumVerb - Aux Track ", numbered: true, shown: true) == "DrumVerb - Aux Track ")
        #expect(try TrackMovePlan.name("4 DrumVerb - Aux Track ", numbered: true, shown: true) == "DrumVerb - Aux Track ")
        #expect(try TrackMovePlan.name(" Drums - Routing Folder Track ", numbered: true, shown: false) == "Drums - Routing Folder Track ")
        #expect(try TrackMovePlan.name(" 12 Drums - Audio Track ", numbered: true, shown: false) == "12 Drums - Audio Track ")
        #expect(try TrackMovePlan.name("4 12 Drums - Audio Track ", numbered: true, shown: true) == "12 Drums - Audio Track ")
        #expect(try TrackMovePlan.name("12 Drums - Audio Track ", numbered: false, shown: false) == "12 Drums - Audio Track ")
        #expect(throws: FloError.unexpectedValue("the shown track's number")) {
            try TrackMovePlan.name("Drums - Audio Track ", numbered: true, shown: true)
        }
        #expect(throws: FloError.unexpectedValue("the hidden track's blank number column")) {
            try TrackMovePlan.name("Drums - Audio Track ", numbered: true, shown: false)
        }
    }

    @Test func dragUsesScrolledTrackListRowsInEitherWindow() {
        let viewport = CGRect(x: 4, y: 80, width: 222, height: 100)
        let down = TrackMovePlan.dragPoints(source: 40, neighbor: 41, direction: .later, rowHeight: 11, viewport: viewport, offset: 440)
        #expect(down.start == CGPoint(x: 115, y: 85.5))
        #expect(down.end == CGPoint(x: 115, y: 101.25))
        let up = TrackMovePlan.dragPoints(source: 41, neighbor: 40, direction: .earlier, rowHeight: 11, viewport: viewport, offset: 440)
        #expect(up.start == CGPoint(x: 115, y: 96.5))
        #expect(up.end == CGPoint(x: 115, y: 80.75))
        #expect(viewport.insetBy(dx: 1, dy: 0.5).contains(up.end))
    }

    @Test func closingAndExpandingFolderMovesEveryMemberTogether() throws {
        let folder = TrackMoveRow(name: "Folder", isShown: false, folder: .open)
        let closed = TrackMoveRow(name: "Folder", isShown: false, folder: .closed)
        let member = TrackMoveRow(name: "Member", isShown: false, folder: nil)
        let aux = TrackMoveRow(name: "Aux", isShown: true, folder: nil)
        let fold = try TrackMoveFold(before: [folder, member, aux], after: [closed, aux], name: "Folder")
        #expect(fold.expanding([aux, closed]) == [aux, folder, member])
        #expect(throws: FloError.couldNot("identify the closed folder's members")) {
            try TrackMoveFold(before: [folder, member, aux], after: [aux, closed], name: "Folder")
        }
    }

    @Test func emptyAndNestedFolderMembersRemainInOrder() throws {
        let outer = TrackMoveRow(name: "Outer", isShown: true, folder: .open)
        let closed = TrackMoveRow(name: "Outer", isShown: true, folder: .closed)
        let inner = TrackMoveRow(name: "Inner", isShown: false, folder: .open)
        let member = TrackMoveRow(name: "Member", isShown: false, folder: nil)
        let fold = try TrackMoveFold(before: [outer, inner, member], after: [closed], name: "Outer")
        #expect(fold.expanding([closed]) == [outer, inner, member])
        #expect(try TrackMoveFold(before: [outer], after: [closed], name: "Outer").expanding([closed]) == [outer])
        #expect(throws: FloError.couldNot("identify the closed folder's members")) {
            try TrackMoveFold(before: [outer, inner, member], after: [closed, member, inner], name: "Outer")
        }
    }

    @Test func speechFollowsWindowDirectionAndReportsBoundaries() {
        #expect(TrackMovement.text(.moved(count: 1, position: 4), direction: .earlier, inMix: true) == "Moved 1 track left, position 4.")
        #expect(TrackMovement.text(.moved(count: 2, position: 6), direction: .later, inMix: false) == "Moved 2 tracks down, position 6.")
        #expect(TrackMovement.text(.noSelection, direction: .earlier, inMix: true) == NoTracks.selected)
        #expect(TrackMovement.text(.atBoundary, direction: .earlier, inMix: false) == "The first selected track is already at the beginning of the Track List.")
        #expect(TrackMovement.text(.atBoundary, direction: .later, inMix: true) == "The last selected track is already at the end of the Track List.")
    }
}
