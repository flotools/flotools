import CoreGraphics
import FloSystem
import Foundation
import Testing
@testable import FloFeatures
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
        _ = await cursor.next()
        await cursor.reset()
        #expect(await cursor.column == .start)
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

    /// The mark keeps the clip's row text without the selection prefix, so selecting the clip does not lose it.
    @Test func clipListName() {
        #expect(ProToolsApp.clipName(rowText: "Selected. Audio Clip \"Guitar_01\"  Timebase selector (samples)") == "Audio Clip \"Guitar_01\"  Timebase selector (samples)")
        #expect(ProToolsApp.clipName(rowText: "Audio Clip \"Bass_02\"") == "Audio Clip \"Bass_02\"")
    }

    @Test func clipDragResult() {
        #expect(ClipDrag.resultText(undoBefore: "Undo Unfreeze Tracks", undoAfter: "Undo Drag from Bin") == "Finished dragging")
        #expect(ClipDrag.resultText(undoBefore: "Undo Unfreeze Tracks", undoAfter: "Undo Unfreeze Tracks") == "Failed dragging.")
        #expect(ClipDrag.resultText(undoBefore: "Undo Drag from Bin", undoAfter: "Undo Drag from Bin") == "Could not tell whether the drag worked.")
        #expect(ClipDrag.resultText(undoBefore: "Undo Drag from Bin", undoAfter: "Undo Nudge") == "Failed dragging.")
    }

    @Test func selectedTracks() {
        #expect(KeyAnnouncements.selectedTracksText(names: []) == "No tracks are selected.")
        #expect(KeyAnnouncements.selectedTracksText(names: ["Kick - Audio Track ", "Bass - MIDI Track "]) == "Kick - Audio. Bass - MIDI. ")
    }
}

@Suite struct SessionStateTests {
    /// Like KM Cleanup Variables on Pro Tools quit: no marked clip, view, gain reduction or event column carries into the next session.
    @AccessibilityActor
    @Test func resetForgetsTheSession() async throws {
        let session = SessionState()
        session.clipMark.set("Audio Clip \"Guitar_01\"", in: Self.window(pid: 1))
        await session.plugInView.load(try PlugInView(json: Data(#"{"view":"Default","click":[-1,-1],"parameters":[[["Gain",1,2]]]}"#.utf8)), for: "EQ3 7-Band")
        await session.gainReduction.record("minus 6 db")
        _ = await session.eventColumn.next()
        await session.reset()
        #expect(session.clipMark.clipName(in: Self.window(pid: 1)) == nil)
        await #expect(throws: FloError.self) { try await session.plugInView.move(for: "EQ3 7-Band", rows: 1, columns: 0) }
        #expect(await session.gainReduction.take() == 0)
        #expect(await session.eventColumn.column == .start)
    }

    /// A mark made in one session's Edit window is not used, and is dropped, once another Edit window is the current one.
    @AccessibilityActor
    @Test func clipMarkBelongsToItsEditWindow() {
        let mark = ClipDragMark()
        mark.set("Audio Clip \"Guitar_01\"", in: Self.window(pid: 1))
        #expect(mark.clipName(in: Self.window(pid: 1)) == "Audio Clip \"Guitar_01\"")
        #expect(mark.clipName(in: Self.window(pid: 2)) == nil)
        #expect(mark.clipName(in: Self.window(pid: 1)) == nil)
    }

    /// Stands in for an Edit window: application elements of different processes are different elements, and creating one needs no Accessibility access.
    @AccessibilityActor
    private static func window(pid: pid_t) -> ProToolsApp.EditWindowIdentity {
        ProToolsApp.EditWindowIdentity(AXElement.application(pid: pid))
    }
}

@Suite struct WindowChangeTests {
    @Test @MainActor func startupWarningDoesNotAssumePermissionFailure() {
        #expect(Lifecycle.startupSpeechFailed == "Flo Tools could not communicate with VoiceOver.")
    }

    /// Like KM's focused window trigger: two instances of one plug-in have the same title but are different windows; coming back from another app is not a new window.
    @Test func focusChangesCountEvenWithTheSameTitle() {
        #expect(Lifecycle.isNewWindow("Plug-in: EQ3", number: 1, after: nil))
        #expect(Lifecycle.isNewWindow("Plug-in: EQ3", number: 4, after: ("Plug-in: EQ3", 3)))
        #expect(!Lifecycle.isNewWindow("Plug-in: EQ3", number: 3, after: ("Plug-in: EQ3", 3)))
        #expect(Lifecycle.isNewWindow("Plug-in: Dyn3", number: 3, after: ("Plug-in: EQ3", 3)))
        #expect(!Lifecycle.isNewWindow("Plug-in: EQ3", number: 9, after: ("Plug-in: EQ3", nil)))
    }
}

@Suite struct AnnouncementGuardTests {
    let edit = FrontWindowFacts(title: "Edit: I Trust", hasCloseButton: true)
    let mix = FrontWindowFacts(title: "Mix: I Trust", hasCloseButton: true)
    let saveDialog = FrontWindowFacts(title: "Save Session As", hasCloseButton: false)
    let otherDialog = FrontWindowFacts(title: "Track Name", hasCloseButton: false)

    /// The KM title pattern `^Dashboard|^Save|Bounce$|^Open|^Get Info|Setup$|^Create Group|...`.
    @Test func listedDialogsMatchTheKeyboardMaestroPattern() {
        #expect(AnnouncementGuard.isListedDialog("Save Session As"))
        #expect(AnnouncementGuard.isListedDialog("Bounce Mix: Bounce"))
        #expect(AnnouncementGuard.isListedDialog("Playback Engine Setup"))
        #expect(AnnouncementGuard.isListedDialog("MIDI Event List"))
        #expect(!AnnouncementGuard.isListedDialog("Edit: I Trust"))
        #expect(!AnnouncementGuard.isListedDialog("Bounce Settings"))
    }

    @Test func textFieldsSilenceTheTextGuards() {
        for guarding in [AnnouncementGuard.outsideListedDialogsAndText, .outsideDialogsAndText] {
            #expect(guarding.readsTextFocus)
            #expect(guarding.allows(edit, hasTextEntryFocus: false))
            #expect(!guarding.allows(edit, hasTextEntryFocus: true))
        }
        #expect(AnnouncementGuard.inEditWindow.allows(edit, hasTextEntryFocus: true))
    }

    @Test func textEntryRolesAreTheFocusedRolesSeenLive() {
        #expect(ProToolsApp.textEntryRoles == ["AXTextArea", "AXTextField"])
        #expect(!ProToolsApp.textEntryRoles.contains("AXUnknown"))
        #expect(!ProToolsApp.textEntryRoles.contains("AXGroup"))
    }

    /// Only listed dialogs silence the playlist and link keys; any window without a close button silences the grid steps.
    @Test func dialogsAreCheckedTheTwoKeyboardMaestroWays() {
        #expect(!AnnouncementGuard.outsideListedDialogsAndText.allows(saveDialog, hasTextEntryFocus: false))
        #expect(AnnouncementGuard.outsideListedDialogsAndText.allows(otherDialog, hasTextEntryFocus: false))
        #expect(!AnnouncementGuard.outsideDialogsAndText.allows(otherDialog, hasTextEntryFocus: false))
        #expect(!AnnouncementGuard.outsideDialogsAndText.allows(nil, hasTextEntryFocus: false))
    }

    @Test func editWindowGuardAndAlways() {
        #expect(AnnouncementGuard.inEditWindow.allows(edit, hasTextEntryFocus: false))
        #expect(!AnnouncementGuard.inEditWindow.allows(mix, hasTextEntryFocus: false))
        #expect(AnnouncementGuard.always.allows(nil, hasTextEntryFocus: true))
        #expect(!AnnouncementGuard.inEditWindow.readsTextFocus)
        #expect(!AnnouncementGuard.always.readsTextFocus)
    }
}

/// The Edit window controls as Pro Tools 26.10 names them, written out in full so a wrong cluster, subgroup, role or name in `EditWindowControl` fails here. The keymap baselines cannot see these.
@Suite struct EditWindowControlTests {
    static func path(_ control: EditWindowControl) -> String {
        let name = switch control.name {
        case .is(let text): "is \(text)"
        case .contains(let text): "contains \(text)"
        }
        return ([control.cluster.rawValue] + control.subgroups + [control.role, name]).joined(separator: " > ")
    }

    @Test func pathsMatchProTools() {
        let expected: [(EditWindowControl, String)] = [
            (.mainCounter, "Counter Display Cluster > AXTextField > is Main Counter"),
            (.subCounter, "Counter Display Cluster > AXTextField > is Sub Counter"),
            (.selectionStart, "Counter Display Cluster > AXTextField > is Edit Selection Start"),
            (.selectionEnd, "Counter Display Cluster > AXTextField > is Edit Selection End"),
            (.selectionLength, "Counter Display Cluster > AXTextField > is Edit Selection Length"),
            (.notePitch, "Counter Display Cluster > AXTextField > is MIDI Note Pitch"),
            (.attackVelocity, "Counter Display Cluster > AXTextField > is MIDI Note Attack Velocity"),
            (.releaseVelocity, "Counter Display Cluster > AXTextField > is MIDI Note Release Velocity"),
            (.mainCounterSelector, "Counter Display Cluster > AXButton > is Main Counter selector"),
            (.subCounterSelector, "Counter Display Cluster > AXButton > is Sub Counter selector"),
            (.preRoll, "Transport View Cluster > Transport Display > AXTextField > is Pre-roll Amount"),
            (.postRoll, "Transport View Cluster > Transport Display > AXTextField > is Post-roll Amount"),
            (.nudgeValue, "Grid/Nudge Cluster > AXTextField > is Nudge Custom Value"),
            (.nudgeSelector, "Grid/Nudge Cluster > AXPopUpButton > is Nudge value"),
            (.gridValue, "Grid/Nudge Cluster > AXPopUpButton > is Grid Value"),
            (.tempo, "MIDI Control Cluster > AXTextField > is Tempo value"),
        ]
        for (control, path) in expected {
            #expect(Self.path(control) == path)
        }
        #expect(EditWindowControl.Cluster.editMode.rawValue == "Edit Mode Cluster")
        #expect(EditWindowControl.Cluster.cursorTool.rawValue == "Cursor Tool Cluster")
    }
}
