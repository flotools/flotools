import CoreGraphics
import FloEngine
import FloProTools
import FloSystem

/// The KM version's beta clip drag: Mark Clip for Drag remembers the clip under the VoiceOver cursor in the clip list and Option-clicks it; Drag Clip, with the VoiceOver cursor on a track name in the Edit window, Control-drags the marked clip to the right end of that track. Mouse steps and modifiers are the KM version's.
///
/// Changed on purpose (2026-11-03): the KM version remembered a screen point, which pointed at another clip once the list scrolled or the window moved, and took a non-empty edit selection as success, which a drop does not change (checked live). Here the mark is the clip's name, found again in the clip list at drag time, and Pro Tools' Edit > Undo item tells whether the drop happened.
enum ClipDrag {
    @MainActor
    static func commands(_ mark: ClipDragMark) -> [Command] {
        [
            Command("floTools.betaMarkClipForDrag", "Beta: Mark Clip for Drag", summary: "Marks the clip under the VoiceOver cursor in the clip list for Drag Clip.", scope: .anyProToolsWindow, triggers: [.key("Opt+Shift+Cmd+,")]) { _ in
                let cursor = try await VoiceOver.cursorBounds()
                let app = try ProToolsApp.running()
                let clip = try await app.listedClip(at: CGPoint(x: cursor.midX, y: cursor.midY)).required("a clip list item under the VoiceOver cursor")
                try await mark.set(clip.name, in: app)
                try await VoiceOver.say("Marked for drag.")
                // The KM version held the button until the hotkey's modifiers were up. It is released however the wait ends.
                let point = grabPoint(of: clip.frame)
                try Mouse.pressButton(at: point, modifiers: .maskAlternate)
                defer { Mouse.releaseButton(at: point, modifiers: .maskAlternate) }
                try await Keyboard.waitForModifiersReleased()
            },
            Command("floTools.betaDragClip", "Beta: Drag Clip", summary: "Drags the marked clip onto the track under the VoiceOver cursor in the Edit window and says whether Pro Tools took it.", scope: .anyProToolsWindow, triggers: [.key("Opt+Shift+Cmd+.")]) { _ in
                try await Keyboard.waitForModifiersReleased()
                let app = try ProToolsApp.running()
                guard let name = try await mark.clipName(in: app) else { throw FloError.notFound("a clip marked for drag") }
                await Sound.done.play()
                let clip = try await app.listedClip(named: name).required("the marked clip in the clip list")
                let start = grabPoint(of: clip.frame)
                let track = try await app.trackUnderVoiceOverCursor(in: .edit)
                let target = dropPoint(onTrack: try await track.frame())
                let undoBefore = try await app.undoItemName()
                try await Mouse.click(at: start, modifiers: .maskControl)
                try await Mouse.drag(from: start, to: target, modifiers: .maskControl)
                // The drop shows in the Undo item after the button is up; a second is ample.
                let undoAfter = try await ProToolsUpdate.reading(changedFrom: undoBefore, within: .seconds(1)) { try app.undoItemName() }
                try await VoiceOver.say(resultText(undoBefore: undoBefore, undoAfter: undoAfter))
            },
        ]
    }

    /// The left edge of the item, halfway down.
    static func grabPoint(of bounds: CGRect) -> CGPoint { CGPoint(x: bounds.minX, y: bounds.midY) }

    /// The right edge of the track, halfway down.
    static func dropPoint(onTrack frame: CGRect) -> CGPoint { CGPoint(x: frame.maxX, y: frame.midY) }

    /// Pro Tools' Undo item after a clip is dropped from the clip list (checked live 2026-11-03).
    static let dropUndoName = "Undo Drag from Bin"

    /// What Drag Clip says, from the Undo item before and after. When it named a drop already, a second drop leaves it as it was, so the result cannot be told.
    static func resultText(undoBefore: String, undoAfter: String) -> String {
        if undoAfter == dropUndoName, undoBefore != dropUndoName { return "Finished dragging" }
        if undoAfter == dropUndoName { return "Could not tell whether the drag worked." }
        return "Failed dragging."
    }
}

/// The clip marked for drag, between Mark Clip for Drag and Drag Clip, by its clip list name and the Edit window it was marked in. Replaces the KM variable point1, which lived until Pro Tools quit: a mark made in one session must not drag a same-named clip of the next session opened in the same Pro Tools.
/// On `AccessibilityActor`, which owns the window element it keeps.
@AccessibilityActor
final class ClipDragMark {
    private var clipName: String?
    private var window: ProToolsApp.EditWindowIdentity?

    nonisolated init() {}

    // The app-taking forms find the Edit window on this actor: its identity holds an element, which cannot be passed from a command body.
    func set(_ clipName: String, in app: ProToolsApp) throws {
        set(clipName, in: try app.editWindowIdentity())
    }

    func set(_ clipName: String, in window: ProToolsApp.EditWindowIdentity) {
        self.window = window
        self.clipName = clipName
    }

    /// The marked clip, nil when none is marked or it was marked in an Edit window that is gone, which also clears the mark.
    func clipName(in app: ProToolsApp) throws -> String? {
        // Nothing marked is "nothing marked", even without an Edit window to compare with.
        guard clipName != nil else { return nil }
        return clipName(in: try app.editWindowIdentity())
    }

    func clipName(in current: ProToolsApp.EditWindowIdentity) -> String? {
        guard let clipName, let window else { return nil }
        guard window.isSame(as: current) else {
            Log.info(.engine, "clip mark dropped: it was made in another session's Edit window")
            clear()
            return nil
        }
        return clipName
    }

    func clear() {
        clipName = nil
        window = nil
    }
}
