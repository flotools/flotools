import Carbon
import Foundation

/// VoiceOver through the Apple events of its scripting dictionary, sent directly rather than through AppleScript source.
/// There is no public API for the VoiceOver cursor, and VoiceOver does not speak accessibility announcements from a background app (tested 2026-11-02), so `output` is the way to speak.
/// Sending the events directly takes about 3 ms instead of about 30 ms for compiling and running AppleScript, passes text as a parameter so nothing needs escaping, and sets a timeout per call.
@MainActor
public enum VoiceOver {
    /// How long to wait for VoiceOver to answer. Without a limit, an Apple event to a VoiceOver that is not answering (for example while its welcome dialog is open) waits about two minutes.
    static let timeout: TimeInterval = 2

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
    public static func cursorText() throws -> String? { try text(under: "vocu", named: "VoiceOver cursor") }

    /// Text under VoiceOver's keyboard cursor, like `vo.keyboardCursor.textUnderCursor()`. Ends with "edit text" on a text field.
    public static func keyboardCursorText() throws -> String? { try text(under: "kbcu", named: "keyboard cursor") }

    /// `text under cursor` (`votx`) of the cursor property `cursor` of the application.
    private static func text(under cursor: String, named name: String) throws -> String? {
        let start = ContinuousClock.now
        let event = voiceOverEvent(eventClass: "core", id: "getd")
        event.setParam(property("votx", of: property(cursor, of: .null())), forKeyword: keyDirectObject)
        let text = try send(event, doing: "read the \(name)").paramDescriptor(forKeyword: keyDirectObject)?.stringValue
        Log.debug(.voiceover, "\(name): \(text.map { "\"\($0)\"" } ?? "no text") (\(Log.elapsed(since: start)))")
        return text
    }

    /// The screen frame of the item in the VoiceOver cursor, like `vo.voCursor.bounds()`, in the global coordinates mouse events use. VoiceOver's `bounds` is a rectangle, which coerces to a list of left, top, right and bottom.
    public static func cursorBounds() throws -> CGRect {
        let event = voiceOverEvent(eventClass: "core", id: "getd")
        event.setParam(property("pbnd", of: property("vocu", of: .null())), forKeyword: keyDirectObject)
        let reply = try send(event, doing: "read the VoiceOver cursor bounds").paramDescriptor(forKeyword: keyDirectObject)
        guard let list = reply?.coerce(toDescriptorType: typeAEList), list.numberOfItems == 4 else {
            throw FloError.unexpectedValue("VoiceOver cursor bounds of type \(reply.map { String(describing: $0.descriptorType) } ?? "none")")
        }
        let edges = (1...4).map { CGFloat(list.atIndex($0)?.doubleValue ?? 0) }
        let frame = CGRect(x: edges[0], y: edges[1], width: edges[2] - edges[0], height: edges[3] - edges[1])
        Log.debug(.voiceover, "VoiceOver cursor bounds: \(frame)")
        return frame
    }

    /// Whether macOS lets Flo Tools control VoiceOver with Apple events, checked without asking the user. For the diagnostic log header.
    public static func automationPermission() -> String {
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

    /// Why an Apple event to VoiceOver failed, in words for the log. `status` is the Apple Event Manager error code.
    static func failureReason(status: Int) -> String {
        switch status {
        case Int(procNotFound), Int(connectionInvalid): "VoiceOver is not running"
        case Int(errAETimeout): "VoiceOver did not answer within \(Int(timeout)) seconds"
        case Int(errAEEventNotPermitted), Int(errAEEventWouldRequireUserConsent): "Flo Tools may not control VoiceOver (Automation permission)"
        default: "Apple event error \(status)"
        }
    }

    // MARK: Apple events

    private static let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.VoiceOver")

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
