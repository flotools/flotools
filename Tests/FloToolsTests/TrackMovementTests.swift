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

    @Test func boundariesAreNoOpsAndNonadjacentSelectionIsRejected() throws {
        #expect(try TrackMovePlan(count: 4, selected: [0, 1], direction: .earlier) == nil)
        #expect(try TrackMovePlan(count: 4, selected: [2, 3], direction: .later) == nil)
        #expect(throws: FloError.couldNot("move nonadjacent tracks; select adjacent tracks first")) {
            try TrackMovePlan(count: 4, selected: [0, 2], direction: .later)
        }
    }

    @Test func invalidSelectionCannotConstructAnInvalidRange() {
        for selected in [[], [2, 0], [-1], [4], [1, 1]] {
            #expect(throws: FloError.couldNot("move nonadjacent tracks; select adjacent tracks first")) {
                try TrackMovePlan(count: 4, selected: selected, direction: .earlier)
            }
        }
    }

    @Test func displayedNumbersAreRemovedWithoutChangingActualNames() throws {
        #expect(try TrackMovePlan.name("4 Audio 5 - Audio Track ", at: 3, numbered: true) == "Audio 5 - Audio Track ")
        #expect(try TrackMovePlan.name("5 Audio 5 - Audio Track ", at: 4, numbered: true) == "Audio 5 - Audio Track ")
        #expect(try TrackMovePlan.name("12 Drums - Audio Track ", at: 2, numbered: false) == "12 Drums - Audio Track ")
        #expect(try TrackMovePlan.name("4 12 Drums - Audio Track ", at: 3, numbered: true) == "12 Drums - Audio Track ")
        #expect(throws: FloError.unexpectedValue("the Track List number at position 4")) {
            try TrackMovePlan.name("5 Audio 5 - Audio Track ", at: 3, numbered: true)
        }
    }

    @Test func dragUsesNativeWindowAxisAndNeighborBoundary() {
        let name = CGRect(x: 500, y: 900, width: 70, height: 16)
        let left = CGRect(x: 400, y: 60, width: 80, height: 950)
        let mix = TrackMovePlan.dragPoints(name: name, neighbor: left, direction: .earlier, layout: .mix)
        #expect(mix.start == CGPoint(x: 535, y: 908))
        #expect(mix.end == CGPoint(x: 401, y: 908))
        let below = CGRect(x: 250, y: 920, width: 400, height: 100)
        let edit = TrackMovePlan.dragPoints(name: name, neighbor: below, direction: .later, layout: .edit)
        #expect(edit.end == CGPoint(x: 535, y: 1019))
    }

    @Test func speechFollowsWindowDirectionAndReportsBoundaries() {
        #expect(TrackMovement.text(.moved(count: 1, position: 4), direction: .earlier, inMix: true) == "Moved 1 track left, position 4.")
        #expect(TrackMovement.text(.moved(count: 2, position: 6), direction: .later, inMix: false) == "Moved 2 tracks down, position 6.")
        #expect(TrackMovement.text(.noSelection, direction: .earlier, inMix: true) == NoTracks.selected)
        #expect(TrackMovement.text(.atBoundary, direction: .earlier, inMix: false) == "Selected tracks are already at the beginning of the Track List.")
        #expect(TrackMovement.text(.atBoundary, direction: .later, inMix: true) == "Selected tracks are already at the end of the Track List.")
    }
}
