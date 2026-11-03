import FloEngine
import FloProTools
import FloSystem

/// Flo Tools Inspector group: works on the Mix window track under the VoiceOver cursor.
enum Inspector {
    @MainActor
    static let macros = [
        Macro("inspector.speakOpenSendB", "Speak/Open Send B", group: .inspector, triggers: [.key("Ctrl+2")]) { _ in sendPress(slot: 1) },
        Macro("inspector.speakToggleSolo", "Speak/Toggle Solo", group: .inspector, triggers: [.key("S")]) { _ in soloPress() },
    ]

    // MARK: Solo

    /// Single press speaks the Solo state of the track under the VoiceOver cursor. Double press clicks Solo and speaks the new state.
    @MainActor
    static func soloPress() {
        DoublePress.shared.press("s", single: {
            guard let solo = Tracks.underVoiceOverCursor()?.button("Solo") else { return }
            VoiceOver.say(soloStateText(solo.value ?? ""))
        }, double: {
            guard let solo = Tracks.underVoiceOverCursor()?.button("Solo") else { return }
            solo.press()
            Task { @MainActor in
                // The JXA waited 0.1 s for Pro Tools to update the button, then spoke, then played Tink.
                try? await Task.sleep(for: .milliseconds(100))
                VoiceOver.say(soloStateText(solo.value ?? ""))
                Sound.play("Tink")
            }
        })
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

    /// Single press speaks the send slot and its assignment. Double press clicks the assignment button.
    @MainActor
    static func sendPress(slot: Int) {
        DoublePress.shared.press("send\(slot)", single: {
            guard let (selector, assignment) = sendButtons(slot: slot) else { return }
            VoiceOver.say(sendMessage(selectorName: selector.name ?? "", selectorValue: selector.value ?? "", assignmentValue: assignment.value ?? ""))
        }, double: {
            guard let (_, assignment) = sendButtons(slot: slot) else { return }
            assignment.press()
            Sound.play("Tink")
        })
    }

    /// Selector and assignment buttons of send slot 0 (A) to 9 (J).
    @MainActor
    static func sendButtons(slot: Int) -> (selector: AXElement, assignment: AXElement)? {
        let groupName = slot < 5 ? "Sends A-E" : "Sends F-J"
        guard let buttons = Tracks.underVoiceOverCursor()?.group(groupName)?.buttons else { return nil }
        let index = (slot % 5) * 2
        guard buttons.count > index + 1 else { return nil }
        return (buttons[index], buttons[index + 1])
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
