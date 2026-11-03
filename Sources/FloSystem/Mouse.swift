import CoreGraphics
import Foundation

/// Synthetic mouse moves and clicks, like Keyboard Maestro's Move or Click Mouse. Points are global screen coordinates with the origin at the top left of the main display, as `AXElement.position` reports them.
///
/// Mouse events go to the window under the pointer, so they are posted to the whole system, not to one app. They carry `Keyboard.syntheticMarker`.
public enum Mouse {
    /// Pro Tools, like for keys, may miss a button up that follows its button down at once, so the button is held this long.
    private static let holdTime: Duration = .milliseconds(10)

    /// Moves the pointer, for example so VoiceOver or a later scroll acts on the control under it.
    public static func move(to point: CGPoint) {
        post(.mouseMoved, at: point)
        Log.info(.hotkeys, "mouse moved to \(text(point))")
    }

    /// Moves the pointer and clicks the left button there, with `modifiers` held, such as `.maskControl`.
    public static func click(at point: CGPoint, modifiers: CGEventFlags = []) async {
        post(.mouseMoved, at: point)
        post(.leftMouseDown, at: point, modifiers: modifiers)
        try? await Task.sleep(for: holdTime)
        // Always released, even when the caller is cancelled during the hold.
        post(.leftMouseUp, at: point, modifiers: modifiers)
        Log.info(.hotkeys, "mouse clicked at \(text(point))")
    }

    /// Moves the pointer and holds the left button down there, until `releaseButton(at:modifiers:)`. The caller must release it, also when it is cancelled.
    public static func pressButton(at point: CGPoint, modifiers: CGEventFlags = []) {
        post(.mouseMoved, at: point)
        post(.leftMouseDown, at: point, modifiers: modifiers)
        Log.info(.hotkeys, "mouse button down at \(text(point))")
    }

    public static func releaseButton(at point: CGPoint, modifiers: CGEventFlags = []) {
        post(.leftMouseUp, at: point, modifiers: modifiers)
        Log.info(.hotkeys, "mouse button up at \(text(point))")
    }

    /// Presses the left button at `start`, drags to `end` and releases it there, with `modifiers` held, like Keyboard Maestro's click and drag.
    public static func drag(from start: CGPoint, to end: CGPoint, modifiers: CGEventFlags = []) async {
        post(.mouseMoved, at: start)
        post(.leftMouseDown, at: start, modifiers: modifiers)
        try? await Task.sleep(for: holdTime)
        post(.leftMouseDragged, at: end, modifiers: modifiers)
        try? await Task.sleep(for: holdTime)
        post(.leftMouseUp, at: end, modifiers: modifiers)
        Log.info(.hotkeys, "mouse dragged from \(text(start)) to \(text(end))")
    }

    /// "x, y" in whole points. Formatted rather than converted with `Int(_:)`, which traps on a value out of range, such as one from a user's view file.
    static func text(_ point: CGPoint) -> String {
        String(format: "%.0f, %.0f", point.x, point.y)
    }

    private static func post(_ type: CGEventType, at point: CGPoint, modifiers: CGEventFlags = []) {
        guard let event = CGEvent(mouseEventSource: CGEventSource(stateID: .hidSystemState), mouseType: type, mouseCursorPosition: point, mouseButton: .left) else {
            Log.warning(.hotkeys, "could not make a mouse event")
            return
        }
        event.flags = modifiers
        event.setIntegerValueField(.eventSourceUserData, value: Keyboard.syntheticMarker)
        event.post(tap: .cghidEventTap)
    }
}
