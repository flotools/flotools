import Foundation
import os

/// VoiceOver through its AppleScript interface. There is no public API for the VoiceOver cursor, and `output` is more reliable than accessibility announcements from a background app.
@MainActor
public enum VoiceOver {
    private static let log = Logger(subsystem: "com.chikim.FloTools", category: "voiceover")
    private static var compiled: [String: NSAppleScript] = [:]

    /// Speaks text through VoiceOver, like `vo.output(...)` in JXA.
    public static func say(_ text: String) {
        log.notice("say: \(text, privacy: .public)")
        run("tell application \"VoiceOver\" to output \"\(escape(text))\"", cache: false)
    }

    /// Text under the VoiceOver cursor, like `vo.voCursor.textUnderCursor()`.
    public static func cursorText() -> String? {
        run("tell application \"VoiceOver\" to return text under cursor of vo cursor")?.stringValue
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
            log.error("AppleScript failed: \(error, privacy: .public)")
            return nil
        }
        return result
    }
}
