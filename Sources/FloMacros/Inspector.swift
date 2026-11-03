import FloEngine
import FloProTools
import FloSystem

/// Flo Tools Inspector group: works on the Mix window track under the VoiceOver cursor.
enum Inspector {
    @MainActor
    static var macros: [Macro] { [
        send("inspector.speakOpenSendB", "Speak/Open Send B", slot: 1, key: "Ctrl+2"),
        // The JXA played Tink, now the done sound, after speaking the new Solo state.
        Macro("inspector.speakToggleSolo", "Speak/Toggle Solo", group: .inspector, triggers: [.key("S")], doneSound: .afterDouble, single: { _ in
            let solo = try await soloButton(in: Tracks.underVoiceOverCursor())
            try await VoiceOver.say(soloStateText(solo.value ?? ""))
        }, double: { _ in
            let solo = try await soloButton(in: Tracks.underVoiceOverCursor())
            try await solo.press()
            // The JXA waited 0.1 s for Pro Tools to update the button before reading it.
            try await Task.sleep(for: .milliseconds(100))
            try await VoiceOver.say(soloStateText(solo.value ?? ""))
        }),
    ] }

    // MARK: Solo

    @AccessibilityActor
    static func soloButton(in strip: AXElement) throws -> AXElement {
        try strip.required("the Solo button") { try $0.button("Solo") }
    }

    /// Same text as the JXA version: "Selected" is "On", empty is "Off", anything else ("off safe") is spoken as is.
    static func soloStateText(_ value: String) -> String {
        switch value {
        case "Selected": "On"
        case "": "Off"
        default: value
        }
    }

    // MARK: Sends

    /// Single press speaks the send slot and its assignment. Double press clicks the assignment button, then plays the done sound, as the JXA played Tink.
    @MainActor
    static func send(_ id: MacroID, _ name: String, slot: Int, key: String) -> Macro {
        Macro(id, name, group: .inspector, triggers: [.key(key)], doneSound: .afterDouble, single: { _ in
            let strip = try await Tracks.underVoiceOverCursor()
            try await VoiceOver.say(sendText(slot: slot, in: strip))
        }, double: { _ in
            let strip = try await Tracks.underVoiceOverCursor()
            try await sendButtons(slot: slot, in: strip).assignment.press()
        })
    }

    /// Selector and assignment buttons of send slot 0 (A) to 9 (J).
    @AccessibilityActor
    static func sendButtons(slot: Int, in strip: AXElement) throws -> (selector: AXElement, assignment: AXElement) {
        let groupName = slot < 5 ? "Sends A-E" : "Sends F-J"
        let buttons = try strip.required("the \(groupName) sends") { try $0.group(groupName) }.buttons
        let index = (slot % 5) * 2
        guard buttons.count > index + 1 else { throw FloError.notFound("the send \(sendLetter(slot)) buttons") }
        return (buttons[index], buttons[index + 1])
    }

    /// What a single press says. Absent names and values are empty, as in the JXA; failed reads throw.
    @AccessibilityActor
    static func sendText(slot: Int, in strip: AXElement) throws -> String {
        let (selector, assignment) = try sendButtons(slot: slot, in: strip)
        return sendMessage(selectorName: try selector.name ?? "", selectorValue: try selector.value ?? "", assignmentValue: try assignment.value ?? "")
    }

    static func sendLetter(_ slot: Int) -> String {
        String(UnicodeScalar(UInt8(ascii: "A") + UInt8(slot)))
    }

    /// Same text as the JXA version, for example " B. : unassigned".
    static func sendMessage(selectorName: String, selectorValue: String, assignmentValue: String) -> String {
        let slot = selectorName.replacingFirst("Send selector", with: "") + ". " + selectorValue.replacingFirst("unassigned", with: "")
        return slot + ": " + assignmentValue.replacingFirst("Send Assignment ", with: "")
    }
}

extension String {
    /// JavaScript's `String.replace` with a string pattern only replaces the first match.
    func replacingFirst(_ target: String, with replacement: String) -> String {
        guard let range = range(of: target) else { return self }
        return replacingCharacters(in: range, with: replacement)
    }
}
