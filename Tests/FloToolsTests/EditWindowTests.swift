import CoreGraphics
import Testing
@testable import FloMacros
@testable import FloProTools

@Suite struct MidiEventTests {
    /// As the six Monitor macros spoke their values.
    @Test func spokenLikeTheMonitors() {
        #expect(MidiEvents.Column.start.spoken("    1| 2| 240") == "Bar 1, Beat 2, Tick 240. start.")
        #expect(MidiEvents.Column.end.spoken("    3| 1| 000") == "Bar 3, Beat 1. End.")
        #expect(MidiEvents.Column.length.spoken("    0| 1| 000") == "1 beat. length.")
        #expect(MidiEvents.Column.pitch.spoken("C#3") == "C-Sharp 3. Pitch")
        #expect(MidiEvents.Column.pitch.spoken("") == "No. Pitch")
        #expect(MidiEvents.Column.attack.spoken("") == "no. Attack")
        #expect(MidiEvents.Column.release.spoken("64") == "64. Release")
    }

    /// Next Column stops at End; Previous Column goes to "No report" before the first column. The KM variable started empty, which the JXA read as the first column.
    @Test func cursorMovesLikeTheJXA() async {
        let cursor = EventColumnCursor()
        #expect(await cursor.column == .start)
        #expect(await cursor.next() == .pitch)
        for _ in 0..<3 { _ = await cursor.next() }
        #expect(await cursor.next() == .end)
        #expect(await cursor.next() == nil)
        #expect(await cursor.column == .end)
        for _ in 0..<5 { _ = await cursor.previous() }
        #expect(await cursor.column == .start)
        #expect(await cursor.previous() == nil)
        #expect(await cursor.column == nil)
        #expect(await cursor.previous() == nil)
        #expect(await cursor.next() == .start)
    }
}

@Suite struct WindowToolsTests {
    @Test func selectedClips() {
        #expect(WindowTools.selectedClipsText([]) == "No clips are currently selected.")
        #expect(WindowTools.selectedClipsText(["\"Kick_01\"", "\"Snare_02\""]) == "2 Selected: \"Kick_01\",\"Snare_02\"")
        #expect(ProToolsApp.quotedClipName("Audio clip \"Kick_01\" selected") == "\"Kick_01\"")
        #expect(ProToolsApp.quotedClipName("no quotes") == nil)
    }

    @Test func resizeEdges() {
        let frame = CGRect(x: 100, y: 200, width: 150.4, height: 300)
        #expect(WindowTools.resizeEdge(.editClips, frame) == CGPoint(x: 99, y: 197))
        #expect(WindowTools.resizeEdge(.frontTrackList, frame) == CGPoint(x: 266.4, y: 200))
        #expect(WindowTools.resizeText(.frontTrackList, width: 150.4) == "Track list table is 150 points wide. Click and drag to resize.")
        #expect(WindowTools.resizeText(.editClips, width: 200) == "Clips table is 200 points wide. Click and drag to resize.")
    }

    @Test func clipDragPoints() {
        let frame = CGRect(x: 10, y: 20, width: 100, height: 40)
        #expect(ClipDrag.grabPoint(of: frame) == CGPoint(x: 10, y: 40))
        #expect(ClipDrag.dropPoint(onTrack: frame) == CGPoint(x: 110, y: 40))
    }

    @Test func selectedTracks() {
        #expect(KeyAnnouncements.selectedTracksText(names: []) == "No tracks are selected.")
        #expect(KeyAnnouncements.selectedTracksText(names: ["Kick - Audio Track ", "Bass - MIDI Track "]) == "Kick - Audio. Bass - MIDI. ")
    }
}
