import Foundation
import Testing
@testable import FloProTools

@Suite struct AutoInspectorNameTests {
    @Test(arguments: [
        "Kick - Audio Track ",
        "Bass - Inst Track ",
        "Drums and Bass - Basic Folder Track ",
        "Bus - Routing Folder Track ",
        "Master - Master Track",
        "VCA 1 - VCA Track ",
        "Video 1 - Video Track ",
        "Lowercase - audio track "
    ])
    func acceptsTrackNameSuffix(_ name: String) {
        let frame = CGRect(x: 86, y: 80, width: 79, height: 1030)
        #expect(ProToolsApp.isInspectorName(text: name, bounds: frame, name: name, frame: frame))
    }

    @Test(arguments: [
        "Counter Display Cluster",
        "Transport",
        "Audio Track",
        "Kick - Audio Track comments",
        "",
        "   "
    ])
    func rejectsUnrelatedGroupEvenWithMatchingBounds(_ name: String) {
        let frame = CGRect(x: 560, y: 61, width: 416, height: 83)
        #expect(!ProToolsApp.isInspectorName(text: name, bounds: frame, name: name, frame: frame))
    }
}
