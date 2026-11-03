import FloEngine
import FloProTools
import FloSystem

/// Flo Tools Inspector group: works on the Mix window track under the VoiceOver cursor.
enum Inspector {
    @MainActor
    static var macros: [Macro] { (0..<10).map(send) + [
        // The JXA played Tink, now the done sound, after speaking the new Solo state.
        Macro("inspector.speakToggleSolo", "Speak/Toggle Solo", group: .inspector, triggers: [.key("S")], doneSound: .afterDouble, single: { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor()
            try await VoiceOver.say(soloStateText(soloValue(of: track)))
        }, double: { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor()
            try await track.soloButton().press()
            // The JXA waited 0.1 s for Pro Tools to update the button before reading it.
            try await Task.sleep(for: .milliseconds(100))
            try await VoiceOver.say(soloStateText(soloValue(of: track)))
        }),
        pan("inspector.panRightOnMonoLeftChannel", "pan right on mono/Left channel", key: "Ctrl+Cmd+Right", .monoOrLeft, .right),
        pan("inspector.panLeftOnMonoLeftChannel", "pan left on mono/Left channel", key: "Ctrl+Cmd+Left", .monoOrLeft, .left),
        pan("inspector.panRightOnRightChannel", "pan right on right channel", key: "Ctrl+Shift+Cmd+Right", .right, .right),
        pan("inspector.panLeftOnRightChannel", "pan left on right channel", key: "Ctrl+Shift+Cmd+Left", .right, .left),
        pan("inspector.panInstrumentRight", "pan Instrument Right", key: "Ctrl+Opt+Right", .instrument, .right),
        pan("inspector.panInstrumentLeft", "pan Instrument left", key: "Ctrl+Opt+Left", .instrument, .left),
    ] }

    // MARK: Solo

    @AccessibilityActor
    static func soloValue(of track: TrackStrip) throws -> String {
        try track.soloButton().value ?? ""
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

    /// Speak/Open Send A to J on Ctrl+1 to Ctrl+0; `slot` counts from 0. Single press speaks the send slot and its assignment. Double press clicks the assignment button, then plays the done sound, as the JXA played Tink. The KM names spelled send H "h"; here it is "H".
    @MainActor
    static func send(slot: Int) -> Macro {
        let letter = TrackStrip.sendLetter(slot)
        return Macro(MacroID("inspector.speakOpenSend\(letter)"), "Speak/Open Send \(letter)", group: .inspector, triggers: [.key("Ctrl+\((slot + 1) % 10)")], doneSound: .afterDouble, single: { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor()
            try await VoiceOver.say(sendText(slot: slot, in: track))
        }, double: { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor()
            try await track.sendButtons(slot: slot).assignment.press()
        })
    }

    /// What a single press says. Absent names and values are empty, as in the JXA; failed reads throw.
    @AccessibilityActor
    static func sendText(slot: Int, in track: TrackStrip) throws -> String {
        let (selector, assignment) = try track.sendButtons(slot: slot)
        return sendMessage(selectorName: try selector.name ?? "", selectorValue: try selector.value ?? "", assignmentValue: try assignment.value ?? "")
    }

    /// Same text as the JXA version, for example " B. : unassigned".
    static func sendMessage(selectorName: String, selectorValue: String, assignmentValue: String) -> String {
        let slot = selectorName.replacingFirst("Send selector", with: "") + ". " + selectorValue.replacingFirst("unassigned", with: "")
        return slot + ": " + assignmentValue.replacingFirst("Send Assignment ", with: "")
    }

    // MARK: Pan

    enum PanDirection: Sendable { case left, right }

    /// Moves one pan control a step and speaks its new position.
    @MainActor
    static func pan(_ id: MacroID, _ name: String, key: String, _ control: TrackStrip.PanControl, _ direction: PanDirection) -> Macro {
        Macro(id, name, group: .inspector, triggers: [.key(key)]) { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor()
            try await VoiceOver.say(step(control, direction, on: track))
        }
    }

    @AccessibilityActor
    static func step(_ control: TrackStrip.PanControl, _ direction: PanDirection, on track: TrackStrip) throws -> String {
        let slider = try track.pan(control)
        switch direction {
        case .right: try slider.increment()
        case .left: try slider.decrement()
        }
        // The JXA spoke the knob's name too, which tells left and right apart; the instrument pan has one control.
        let name = control == .instrument ? nil : try slider.name ?? ""
        return panMessage(valueDescription: try slider.valueDescription ?? "", knobName: name)
    }

    /// Same text as the JXA version, for example "70 to the left, Pan Knob", or "Centered" for an instrument.
    static func panMessage(valueDescription: String, knobName: String?) -> String {
        guard let knobName else { return valueDescription }
        return valueDescription + ", " + knobName
    }
}

extension String {
    /// JavaScript's `String.replace` with a string pattern only replaces the first match.
    func replacingFirst(_ target: String, with replacement: String) -> String {
        guard let range = range(of: target) else { return self }
        return replacingCharacters(in: range, with: replacement)
    }
}
