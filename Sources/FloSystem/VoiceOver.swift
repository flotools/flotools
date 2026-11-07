import Carbon
import Foundation

/// Where Apple events to VoiceOver are sent and waited for, off the main actor.
@globalActor
public actor VoiceOverActor {
    public static let shared = VoiceOverActor()
}

/// VoiceOver through the Apple events of its scripting dictionary, sent directly rather than through AppleScript source.
/// There is no public API for the VoiceOver cursor, and VoiceOver does not speak accessibility announcements from a background app (tested 2026-11-02), so `output` is the way to speak.
/// Sending the events directly takes about 3 ms instead of about 30 ms for compiling and running AppleScript, passes text as a parameter so nothing needs escaping, and sets a timeout per call.
/// Owned by `VoiceOverActor`: an event waits for VoiceOver's reply, up to `timeout`, and an unresponsive VoiceOver must not hold up the main actor, which routes hotkeys and runs the menu. The actor sends one event at a time; each caller awaits its calls, so its own speech stays in order. Separate callers get no first-come order.
@VoiceOverActor
public enum VoiceOver {
    /// How long to wait for VoiceOver to answer. Without a limit, an Apple event to a VoiceOver that is not answering (for example while its welcome dialog is open) waits about two minutes.
    nonisolated static let timeout: TimeInterval = 2

    /// Speaks text through VoiceOver, like `vo.output(...)` in JXA.
    public static func say(_ text: String) throws {
        let start = ContinuousClock.now
        let event = voiceOverEvent(eventClass: "VOAS", id: "outp")
        event.setParam(NSAppleEventDescriptor(string: text), forKeyword: keyDirectObject)
        try send(event, doing: "speak")
        Log.info(.voiceover, "say \"\(text)\" (\(Log.elapsed(since: start)))")
    }

    /// Speaks text for a caller that has nobody to report a failure to: the app's own messages and the engine's spoken failures. A failure is logged instead of thrown.
    public static func sayOrLog(_ text: String) {
        do {
            try say(text)
        } catch {
            Log.error(.voiceover, "could not say \"\(text)\": \(error)")
        }
    }

    /// Text under the VoiceOver cursor, like `vo.voCursor.textUnderCursor()`. Nil when the item under the cursor has no text.
    public static func cursorText() throws -> String? {
        let start = ContinuousClock.now
        let text = try cursorProperty("votx", doing: "read the VoiceOver cursor")?.stringValue
        Log.debug(.voiceover, "VoiceOver cursor: \(text.map { "\"\($0)\"" } ?? "no text") (\(Log.elapsed(since: start)))")
        return text
    }

    /// Read together on this actor, without suspension between the two Apple events.
    public static func cursorSnapshot() throws -> (text: String?, bounds: CGRect) {
        (try cursorText(), try cursorBounds())
    }

    /// The screen frame of the item in the VoiceOver cursor, like `vo.voCursor.bounds()`, in the global coordinates mouse events use. VoiceOver answers with a QuickDraw rectangle (`'qdrt'`), which does not coerce to a list (checked live 2026-11-03).
    public static func cursorBounds() throws -> CGRect {
        let reply = try cursorProperty("pbnd", doing: "read the VoiceOver cursor bounds")
        guard let reply, reply.descriptorType == typeQDRectangle, let frame = frame(quickDrawRect: reply.data) else {
            throw FloError.unexpectedValue("VoiceOver cursor bounds of type \(reply.map { String(describing: $0.descriptorType) } ?? "none")")
        }
        Log.debug(.voiceover, "VoiceOver cursor bounds: \(frame)")
        return frame
    }

    /// The property `code` of the VoiceOver cursor (`vocu`), as VoiceOver answers it.
    private static func cursorProperty(_ code: String, doing what: String) throws -> NSAppleEventDescriptor? {
        let event = voiceOverEvent(eventClass: "core", id: "getd")
        event.setParam(property(code, of: property("vocu", of: .null())), forKeyword: keyDirectObject)
        return try send(event, doing: what).paramDescriptor(forKeyword: keyDirectObject)
    }

    /// A QuickDraw `Rect`: four Int16 in host byte order, top, left, bottom, right. Nil when the data is not 8 bytes.
    nonisolated static func frame(quickDrawRect data: Data) -> CGRect? {
        guard data.count == 8 else { return nil }
        let edges = (0..<4).map { index in data.withUnsafeBytes { CGFloat($0.loadUnaligned(fromByteOffset: index * 2, as: Int16.self)) } }
        return CGRect(x: edges[1], y: edges[0], width: edges[3] - edges[1], height: edges[2] - edges[0])
    }

    /// Whether macOS lets Flo Tools control VoiceOver with Apple events, checked without asking the user. For the diagnostic log header. Nonisolated so the synchronous header can call it: it sends no event to VoiceOver and does not ask the user, so it should return quickly, although the API does not promise that. It has its own target descriptor, which is not Sendable.
    public nonisolated static func automationPermission() -> String {
        guard let desc = NSAppleEventDescriptor(bundleIdentifier: bundleID).aeDesc else { return "unknown" }
        let status = AEDeterminePermissionToAutomateTarget(desc, typeWildCard, typeWildCard, false)
        switch status {
        case noErr: return "granted"
        case OSStatus(errAEEventNotPermitted): return "denied"
        case OSStatus(errAEEventWouldRequireUserConsent): return "not asked yet"
        case OSStatus(procNotFound): return "unknown (VoiceOver not running)"
        default: return "unknown (OSStatus \(status))"
        }
    }

    /// Why an Apple event to VoiceOver failed, in words for the log. `status` is the Apple Event Manager error code.
    nonisolated static func failureReason(status: Int) -> String {
        switch status {
        case Int(procNotFound), Int(connectionInvalid): "VoiceOver is not running"
        case Int(errAETimeout): "VoiceOver did not answer within \(Int(timeout)) seconds"
        case Int(errAEEventNotPermitted), Int(errAEEventWouldRequireUserConsent): "Flo Tools may not control VoiceOver (Automation permission)"
        default: "Apple event error \(status)"
        }
    }

    // MARK: Apple events

    private nonisolated static let bundleID = "com.apple.VoiceOver"
    private static let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)

    private static func voiceOverEvent(eventClass: String, id: String) -> NSAppleEventDescriptor {
        NSAppleEventDescriptor(eventClass: fourCharCode(eventClass), eventID: fourCharCode(id), targetDescriptor: target,
                               returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
    }

    /// Sends an event and waits for the reply. A failure in sending or an error number in the reply throws `FloError.voiceOver`.
    @discardableResult
    private static func send(_ event: NSAppleEventDescriptor, doing action: String) throws -> NSAppleEventDescriptor {
        let reply: NSAppleEventDescriptor
        do {
            reply = try event.sendEvent(options: [.waitForReply], timeout: timeout)
        } catch let error as NSError {
            throw FloError.voiceOver("could not \(action): \(failureReason(status: error.code))")
        }
        if let number = reply.paramDescriptor(forKeyword: keyErrorNumber)?.int32Value, number != noErr {
            throw FloError.voiceOver("could not \(action): \(failureReason(status: Int(number)))")
        }
        return reply
    }

    private static func property(_ code: String, of container: NSAppleEventDescriptor) -> NSAppleEventDescriptor {
        let record = NSAppleEventDescriptor.record()
        record.setDescriptor(NSAppleEventDescriptor(typeCode: DescType(typeProperty)), forKeyword: AEKeyword(keyAEDesiredClass))
        record.setDescriptor(NSAppleEventDescriptor(enumCode: DescType(formPropertyID)), forKeyword: AEKeyword(keyAEKeyForm))
        record.setDescriptor(NSAppleEventDescriptor(typeCode: fourCharCode(code)), forKeyword: AEKeyword(keyAEKeyData))
        record.setDescriptor(container, forKeyword: AEKeyword(keyAEContainer))
        // Coercing a record to an object specifier is how Cocoa builds specifiers; it only fails for a malformed record.
        guard let specifier = record.coerce(toDescriptorType: DescType(typeObjectSpecifier)) else {
            preconditionFailure("object specifier for \(code) could not be built")
        }
        return specifier
    }

    private static func fourCharCode(_ code: String) -> FourCharCode {
        precondition(code.utf8.count == 4, "Apple event codes have four characters: \(code)")
        return code.utf8.reduce(0) { ($0 << 8) | FourCharCode($1) }
    }
}
