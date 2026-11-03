import CoreGraphics
import FloEngine
import FloProTools
import FloSystem

/// The KM version's beta clip drag: Mark Clip for Drag remembers the clip under the VoiceOver cursor and Option-clicks it; Drag Clip, with the VoiceOver cursor on a track name in the Edit window, Control-drags the marked clip to the right end of that track, and checks the edit selection to tell whether it worked. Mouse steps and modifiers are the KM version's.
enum ClipDrag {
    @MainActor
    static var macros: [Macro] {
        let mark = ClipDragMark()
        return [
            Macro("floTools.betaMarkClipForDrag", "Beta: Mark Clip for Drag", group: .floTools, triggers: [.key("Opt+Shift+Cmd+,")]) { _ in
                let point = grabPoint(of: try await VoiceOver.cursorBounds())
                await mark.set(point)
                try await VoiceOver.say("Marked for drag.")
                // The KM version held the button until the hotkey's modifiers were up. It is released however the wait ends.
                Mouse.pressButton(at: point, modifiers: .maskAlternate)
                defer { Mouse.releaseButton(at: point, modifiers: .maskAlternate) }
                try await Keyboard.waitForModifiersReleased()
            },
            Macro("floTools.betaDragClip", "Beta: Drag Clip", group: .floTools, triggers: [.key("Opt+Shift+Cmd+.")]) { _ in
                try await Keyboard.waitForModifiersReleased()
                guard let start = await mark.point else { throw FloError.notFound("a clip marked for drag") }
                await Sound.done.play()
                let app = try ProToolsApp.running()
                let track = try await app.trackUnderVoiceOverCursor(in: .edit)
                let target = dropPoint(onTrack: try await track.frame())
                await Mouse.click(at: start, modifiers: .maskControl)
                await Mouse.drag(from: start, to: target, modifiers: .maskControl)
                let moved = try await ProToolsUpdate.reading(changedFrom: "empty") { try selectionIsEmpty(app) ? "empty" : "selected" }
                try await VoiceOver.say(moved == "selected" ? "Finished dragging" : "Failed dragging.")
            },
        ]
    }

    /// The left edge of the item in the VoiceOver cursor, halfway down.
    static func grabPoint(of bounds: CGRect) -> CGPoint { CGPoint(x: bounds.minX, y: bounds.midY) }

    /// The right edge of the track, halfway down.
    static func dropPoint(onTrack frame: CGRect) -> CGPoint { CGPoint(x: frame.maxX, y: frame.midY) }

    /// Whether the edit selection starts where it ends, which the JXA took as a failed drag.
    @AccessibilityActor
    private static func selectionIsEmpty(_ app: ProToolsApp) throws -> Bool {
        let start = try app.element(Counters.counter("Edit Selection Start")).value
        let end = try app.element(Counters.counter("Edit Selection End")).value
        return start == end
    }
}

/// Where the marked clip is, between Mark Clip for Drag and Drag Clip. Replaces the KM variable point1.
actor ClipDragMark {
    private(set) var point: CGPoint?

    func set(_ point: CGPoint) { self.point = point }
}
