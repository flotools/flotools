import AppKit
import CoreGraphics

/// Synthetic mouse moves and clicks, like Keyboard Maestro's Move or Click Mouse. Points are global screen coordinates with the origin at the top left of the main display, as `AXElement.position` reports them.
///
/// Mouse events go to the window under the pointer, so they are posted to the whole system, not to one app. Each operation therefore names the app it is meant for, `ifFront`, and posts nothing when another app has come to front meanwhile, for example while the command was speaking. The check and the post are not atomic, so this narrows the race rather than closing it. Events carry `Keyboard.syntheticMarker`.
public enum Mouse {
    /// Pro Tools, like for keys, may miss a button up that follows its button down at once, so the button is held this long.
    private static let holdTime: Duration = .milliseconds(10)

    /// Moves the pointer, for example so VoiceOver or a later scroll acts on the control under it.
    public static func move(to point: CGPoint, ifFront pid: pid_t) throws {
        let move = try event(.mouseMoved, at: point)
        try requireFront(pid, "move the mouse")
        move.post(tap: .cghidEventTap)
        Log.info(.hotkeys, "mouse moved to \(text(point))")
    }

    /// Moves the pointer and clicks the left button there, with `modifiers` held, such as `.maskControl`. Throws `CancellationError` without clicking when the caller is already cancelled, because mouse events go to whatever window is under the pointer. All events are made before the first is posted, so a failure to make one never leaves the button down.
    public static func click(at point: CGPoint, modifiers: CGEventFlags = [], ifFront pid: pid_t) async throws {
        try Task.checkCancellation()
        let events = try [event(.mouseMoved, at: point), event(.leftMouseDown, at: point, modifiers: modifiers), event(.leftMouseUp, at: point, modifiers: modifiers)]
        try requireFront(pid, "click")
        events[0].post(tap: .cghidEventTap)
        events[1].post(tap: .cghidEventTap)
        try? await Task.sleep(for: holdTime)
        // Always released, even when the caller is cancelled during the hold.
        events[2].post(tap: .cghidEventTap)
        Log.info(.hotkeys, "mouse clicked at \(text(point))")
    }

    /// Moves the pointer and holds the left button down there, until `releaseButton(at:modifiers:)`. The caller must release it, also when it is cancelled; when this throws, the button was not pressed.
    public static func pressButton(at point: CGPoint, modifiers: CGEventFlags = [], ifFront pid: pid_t) throws {
        let events = try [event(.mouseMoved, at: point), event(.leftMouseDown, at: point, modifiers: modifiers)]
        try requireFront(pid, "press the mouse button")
        for event in events { event.post(tap: .cghidEventTap) }
        Log.info(.hotkeys, "mouse button down at \(text(point))")
    }

    /// Does not throw, so it can run in a `defer`; a failure is logged.
    public static func releaseButton(at point: CGPoint, modifiers: CGEventFlags = []) {
        do {
            try event(.leftMouseUp, at: point, modifiers: modifiers).post(tap: .cghidEventTap)
            Log.info(.hotkeys, "mouse button up at \(text(point))")
        } catch {
            Log.error(.hotkeys, "could not release the mouse button at \(text(point)): \(error)")
        }
    }

    /// Presses the left button at `start`, drags to `end` and releases it there, with `modifiers` held, like Keyboard Maestro's click and drag. Throws `CancellationError` without pressing when already cancelled; cancelled during the first hold, it releases the button where it was pressed, without dragging.
    public static func drag(from start: CGPoint, to end: CGPoint, modifiers: CGEventFlags = [], ifFront pid: pid_t) async throws {
        try Task.checkCancellation()
        let move = try event(.mouseMoved, at: start)
        let down = try event(.leftMouseDown, at: start, modifiers: modifiers)
        let upAtStart = try event(.leftMouseUp, at: start, modifiers: modifiers)
        let dragged = try event(.leftMouseDragged, at: end, modifiers: modifiers)
        let upAtEnd = try event(.leftMouseUp, at: end, modifiers: modifiers)
        try requireFront(pid, "drag")
        move.post(tap: .cghidEventTap)
        down.post(tap: .cghidEventTap)
        try? await Task.sleep(for: holdTime)
        guard !Task.isCancelled else {
            upAtStart.post(tap: .cghidEventTap)
            Log.info(.hotkeys, "mouse drag cancelled, button released at \(text(start))")
            throw CancellationError()
        }
        dragged.post(tap: .cghidEventTap)
        // Once dragged, the button is released at the end even when cancelled, so the drag is not left half done.
        try? await Task.sleep(for: holdTime)
        upAtEnd.post(tap: .cghidEventTap)
        Log.info(.hotkeys, "mouse dragged from \(text(start)) to \(text(end))")
    }

    /// "x, y" in whole points. Formatted rather than converted with `Int(_:)`, which traps on a value out of range, such as one from a user's view file.
    static func text(_ point: CGPoint) -> String {
        String(format: "%.0f, %.0f", point.x, point.y)
    }

    /// Throws `FloError.couldNot` naming `action` when app `pid` is not the front app. A release is never checked: a button that is down must come up.
    private static func requireFront(_ pid: pid_t, _ action: String) throws {
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        guard front == pid else {
            Log.info(.hotkeys, "did not \(action): app \(front.map(String.init) ?? "none") is in front, not \(pid)")
            throw FloError.couldNot("\(action), because another app is in front")
        }
    }

    /// A marked mouse event, or `FloError.couldNot` when macOS cannot make one.
    private static func event(_ type: CGEventType, at point: CGPoint, modifiers: CGEventFlags = []) throws -> CGEvent {
        guard let event = CGEvent(mouseEventSource: CGEventSource(stateID: .hidSystemState), mouseType: type, mouseCursorPosition: point, mouseButton: .left) else {
            throw FloError.couldNot("make a mouse event")
        }
        event.flags = modifiers
        event.setIntegerValueField(.eventSourceUserData, value: Keyboard.syntheticMarker)
        return event
    }
}
