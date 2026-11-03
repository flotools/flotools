import FloEngine
import FloProTools
import FloSystem

/// Flo Tools Inspector group: works on the Mix window track under the VoiceOver cursor.
enum Inspector {
    @MainActor
    static var macros: [Macro] { [
        send("inspector.speakOpenSendB", "Speak/Open Send B", slot: 1, key: "Ctrl+2"),
        // The JXA played Tink after speaking the new Solo state.
        Macro("inspector.speakToggleSolo", "Speak/Toggle Solo", group: .inspector, triggers: [.key("S")], tink: .afterDouble, single: { _ in
            VoiceOver.say(soloStateText(try soloButton().value ?? ""))
        }, double: { _ in
            let solo = try soloButton()
            solo.press()
            // The JXA waited 0.1 s for Pro Tools to update the button before reading it.
            try await Task.sleep(for: .milliseconds(100))
            VoiceOver.say(soloStateText(solo.value ?? ""))
        }),
    ] }

    // MARK: Solo

    @MainActor
    static func soloButton() throws -> AXElement {
        try Tracks.underVoiceOverCursor().button("Solo").required("the Solo button")
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

    /// Single press speaks the send slot and its assignment. Double press clicks the assignment button, then plays Tink as the JXA did.
    @MainActor
    static func send(_ id: MacroID, _ name: String, slot: Int, key: String) -> Macro {
        Macro(id, name, group: .inspector, triggers: [.key(key)], tink: .afterDouble, single: { _ in
            let (selector, assignment) = try sendButtons(slot: slot)
            VoiceOver.say(sendMessage(selectorName: selector.name ?? "", selectorValue: selector.value ?? "", assignmentValue: assignment.value ?? ""))
        }, double: { _ in
            try sendButtons(slot: slot).assignment.press()
        })
    }

    /// Selector and assignment buttons of send slot 0 (A) to 9 (J).
    @MainActor
    static func sendButtons(slot: Int) throws -> (selector: AXElement, assignment: AXElement) {
        let groupName = slot < 5 ? "Sends A-E" : "Sends F-J"
        let buttons = try Tracks.underVoiceOverCursor().group(groupName).required("the \(groupName) sends").buttons
        let index = (slot % 5) * 2
        guard buttons.count > index + 1 else { throw FloError.notFound("the send \(sendLetter(slot)) buttons") }
        return (buttons[index], buttons[index + 1])
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
