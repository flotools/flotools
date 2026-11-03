import CoreGraphics

/// Synthetic mouse moves and clicks, like Keyboard Maestro's Move or Click Mouse. Points are global screen coordinates with the origin at the top left of the main display, as `AXElement.position` reports them.
///
/// Mouse events go to the window under the pointer, so they are posted to the whole system, not to one app. They carry `Keyboard.syntheticMarker`.
public enum Mouse {
    /// Pro Tools, like for keys, may miss a button up that follows its button down at once, so the button is held this long.
    private static let holdTime: Duration = .milliseconds(10)

    /// Moves the pointer, for example so VoiceOver or a later scroll acts on the control under it.
    public static func move(to point: CGPoint) {
        post(.mouseMoved, at: point)
        Log.info(.hotkeys, "mouse moved to \(Int(point.x)), \(Int(point.y))")
    }

    /// Moves the pointer and clicks the left button there.
    public static func click(at point: CGPoint) async {
        post(.mouseMoved, at: point)
        post(.leftMouseDown, at: point)
        try? await Task.sleep(for: holdTime)
        // Always released, even when the caller is cancelled during the hold.
        post(.leftMouseUp, at: point)
        Log.info(.hotkeys, "mouse clicked at \(Int(point.x)), \(Int(point.y))")
    }

    private static func post(_ type: CGEventType, at point: CGPoint) {
        guard let event = CGEvent(mouseEventSource: CGEventSource(stateID: .hidSystemState), mouseType: type, mouseCursorPosition: point, mouseButton: .left) else {
            Log.warning(.hotkeys, "could not make a mouse event")
            return
        }
        event.setIntegerValueField(.eventSourceUserData, value: Keyboard.syntheticMarker)
        event.post(tap: .cghidEventTap)
    }
}
