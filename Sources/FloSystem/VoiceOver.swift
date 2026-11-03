import Foundation

/// VoiceOver through its AppleScript interface. There is no public API for the VoiceOver cursor, and `output` is more reliable than accessibility announcements from a background app.
@MainActor
public enum VoiceOver {
    private static var compiled: [String: NSAppleScript] = [:]

    /// Speaks text through VoiceOver, like `vo.output(...)` in JXA.
    public static func say(_ text: String) {
        let start = ContinuousClock.now
        run("tell application \"VoiceOver\" to output \"\(escape(text))\"", cache: false)
        Log.info(.voiceover, "say \"\(text)\" (\(Log.elapsed(since: start)))")
    }

    /// Whether macOS lets Flo Tools control VoiceOver with Apple events, checked without asking the user. For the diagnostic log header.
    public static func automationPermission() -> String {
        let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.VoiceOver")
        guard let desc = target.aeDesc else { return "unknown" }
        let status = AEDeterminePermissionToAutomateTarget(desc, typeWildCard, typeWildCard, false)
        switch status {
        case noErr: return "granted"
        case OSStatus(errAEEventNotPermitted): return "denied"
        case OSStatus(errAEEventWouldRequireUserConsent): return "not asked yet"
        case OSStatus(procNotFound): return "unknown (VoiceOver not running)"
        default: return "unknown (OSStatus \(status))"
        }
    }

    /// Text under the VoiceOver cursor, like `vo.voCursor.textUnderCursor()`.
    public static func cursorText() -> String? {
        let start = ContinuousClock.now
        let text = run("tell application \"VoiceOver\" to return text under cursor of vo cursor")?.stringValue
        Log.debug(.voiceover, "VoiceOver cursor: \(text.map { "\"\($0)\"" } ?? "nil") (\(Log.elapsed(since: start)))")
        return text
    }

    /// Text under the keyboard cursor, like `vo.keyboardCursor.textUnderCursor()`.
    public static func keyboardCursorText() -> String? {
        run("tell application \"VoiceOver\" to return text under cursor of keyboard cursor")?.stringValue
    }

    /// The last phrase VoiceOver spoke. Useful for checking output.
    public static func lastPhrase() -> String? {
        run("tell application \"VoiceOver\" to return content of last phrase")?.stringValue
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    @discardableResult
    private static func run(_ source: String, cache: Bool = true) -> NSAppleEventDescriptor? {
        let script: NSAppleScript
        if cache, let existing = compiled[source] {
            script = existing
        } else {
            guard let created = NSAppleScript(source: source) else { return nil }
            script = created
            if cache { compiled[source] = created }
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            Log.error(.voiceover, "AppleScript failed: \(error)")
            return nil
        }
        return result
    }
}
