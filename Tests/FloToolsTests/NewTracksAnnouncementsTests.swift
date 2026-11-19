import Testing
@testable import FloFeatures

@Suite struct NewTracksAnnouncementsTests {
    @Test func singleRowSpeaksOnlyItsValueIncludingAnUnchangedValue() {
        #expect(NewTracksAnnouncements.selectionText(before: ["Mono"], after: ["Stereo"]) == "Stereo")
        #expect(NewTracksAnnouncements.selectionText(before: ["Audio Track"], after: ["Audio Track"]) == "Audio Track")
        #expect(NewTracksAnnouncements.selectionText(before: nil, after: ["Ticks"]) == "Ticks")
    }

    @Test func multipleRowsIdentifyOnlyChangedValues() {
        #expect(NewTracksAnnouncements.selectionText(before: ["Mono", "Mono"], after: ["Mono", "Stereo"]) == "Row 2, Stereo")
        #expect(NewTracksAnnouncements.selectionText(before: ["Samples", "Samples"], after: ["Ticks", "Ticks"]) == "Row 1, Ticks. Row 2, Ticks")
    }

    @Test func unknownOrUnchangedRowSpeaksAllCurrentValues() {
        #expect(NewTracksAnnouncements.selectionText(before: ["Mono", "Stereo"], after: ["Mono", "Stereo"]) == "Row 1, Mono. Row 2, Stereo")
        #expect(NewTracksAnnouncements.selectionText(before: nil, after: ["Mono", "Stereo"]) == "Row 1, Mono. Row 2, Stereo")
    }

    @Test func rowCountDoesNotImplyThatTracksWereCreated() {
        #expect(NewTracksAnnouncements.rowCountText(1) == "1 track row")
        #expect(NewTracksAnnouncements.rowCountText(3) == "3 track rows")
    }
}
