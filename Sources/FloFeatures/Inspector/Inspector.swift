import FloEngine
import FloProTools
import FloSystem

/// The Flo Tools Inspector keys work on the Mix window track under the VoiceOver cursor.
enum Inspector {
    @MainActor
    static var commands: [Command] { (0..<10).flatMap { [slot(.insert, $0), assign(.insert, $0), slot(.send, $0), assign(.send, $0)] } + [
        toggle("inspector.speakToggleSolo", "Speak/Toggle Solo", key: "S", .solo),
        toggle("inspector.speakToggleMute", "Speak/Toggle Mute", key: "M", .mute),
        toggle("inspector.speakToggleRecordState", "Speak/Toggle Record State", key: "R", .recordEnable),
        toggle("inspector.speakToggleInputMonitor", "Speak/Toggle Input Monitor", key: "K", .inputMonitor),
        toggle("inspector.speakToggleInstrumentMute", "Speak/Toggle Instrument Mute", key: "Opt+M", .instrumentMute),
        pan("inspector.panRightOnMonoLeftChannel", "pan right on mono/Left channel", key: "Ctrl+Cmd+Right", .monoOrLeft, .increase),
        pan("inspector.panLeftOnMonoLeftChannel", "pan left on mono/Left channel", key: "Ctrl+Cmd+Left", .monoOrLeft, .decrease),
        pan("inspector.panRightOnRightChannel", "pan right on right channel", key: "Ctrl+Shift+Cmd+Right", .right, .increase),
        pan("inspector.panLeftOnRightChannel", "pan left on right channel", key: "Ctrl+Shift+Cmd+Left", .right, .decrease),
        pan("inspector.panInstrumentRight", "pan Instrument Right", key: "Ctrl+Opt+Right", .instrument, .increase),
        pan("inspector.panInstrumentLeft", "pan Instrument left", key: "Ctrl+Opt+Left", .instrument, .decrease),
    ] }

    // MARK: Toggles

    /// Single press speaks the toggle's state; double press presses the button and speaks the new state, then plays the done sound, as the JXA played Tink. The JXA waited a fixed 0.1 s before reading (Record State did not wait); this waits until the state changes.
    @MainActor
    static func toggle(_ id: CommandID, _ name: String, key: String, _ toggle: TrackStrip.Toggle) -> Command {
        Command(id, name, scope: .mixOrEdit, mode: .inspectorOn, triggers: [.key(key)], doneSound: .afterDouble, single: { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor()
            try await VoiceOver.say(stateText(toggle, track.state(of: toggle)))
        }, double: { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor()
            // A track without an input and output cannot be armed or monitored; Pro Tools shows a dialog and the state stays as it was.
            let after = try await track.press(toggle)
            try await VoiceOver.say(stateText(toggle, after))
        })
    }

    /// Same text as the JXA version. Off is an empty state; other states not listed (such as "off safe" or "armed") are spoken as Pro Tools shows them.
    static func stateText(_ toggle: TrackStrip.Toggle, _ state: String) -> String {
        switch (toggle, state) {
        case (.solo, "Selected"), (.mute, "on state"), (.instrumentMute, "on state"): "On"
        case (.recordEnable, ""): "Not Armed"
        case (_, ""): "Off"
        default: state
        }
    }

    // MARK: Inserts and sends

    /// Speak/Open Insert A to J on 1 to 0, and Speak/Open Send A to J on Ctrl+1 to Ctrl+0; `slot` counts from 0. Single press speaks the slot and its assignment. Double press clicks the assignment button, then plays the done sound, as the JXA played Tink. The KM names spelled H "h"; here it is "H".
    @MainActor
    static func slot(_ kind: TrackStrip.SlotKind, _ slot: Int) -> Command {
        let letter = TrackStrip.slotLetter(slot)
        let digit = "\((slot + 1) % 10)"
        let key = kind == .send ? "Ctrl+" + digit : digit
        return Command(CommandID("inspector.speakOpen\(kind.rawValue)\(letter)"), "Speak/Open \(kind.rawValue) \(letter)", scope: .mixOrEdit, mode: .inspectorOn, triggers: [.key(key)], doneSound: .afterDouble, single: { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor()
            try await VoiceOver.say(slotText(kind, slot, in: track))
        }, double: { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor()
            try await track.slotButtons(kind, slot: slot).assignment.pressOpeningMenu()
        })
    }

    /// Assign Insert A to J on Cmd+1 to Cmd+0, and Assign Send A to J on Ctrl+Cmd+1 to Ctrl+Cmd+0: clicks the slot's selector button, which opens Pro Tools' assignment menu. Silent, as in the JXA; VoiceOver reads the menu.
    @MainActor
    static func assign(_ kind: TrackStrip.SlotKind, _ slot: Int) -> Command {
        let letter = TrackStrip.slotLetter(slot)
        let key = (kind == .send ? "Ctrl+Cmd+" : "Cmd+") + "\((slot + 1) % 10)"
        return Command(CommandID("inspector.assign\(kind.rawValue)\(letter)"), "Assign \(kind.rawValue) \(letter)", scope: .mixOrEdit, mode: .inspectorOn, triggers: [.key(key)]) { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor()
            try await track.slotButtons(kind, slot: slot).selector.pressOpeningMenu()
        }
    }

    /// What a single press says. Absent names and values are empty, as in the JXA; failed reads throw.
    @AccessibilityActor
    static func slotText(_ kind: TrackStrip.SlotKind, _ slot: Int, in track: TrackStrip) throws -> String {
        slotMessage(try track.slotReading(kind, slot: slot))
    }

    /// Same text as the JXA version, for example " B. : unassigned" or " A. inactive: SSL Native Channelstrip v6".
    static func slotMessage(_ reading: TrackStrip.SlotReading) -> String {
        reading.letter + ". " + reading.state + ": " + reading.assignment
    }

    // MARK: Pan

    /// Moves one pan control a step and speaks its new position.
    @MainActor
    static func pan(_ id: CommandID, _ name: String, key: String, _ control: TrackStrip.PanControl, _ direction: SliderStep) -> Command {
        Command(id, name, scope: .mixOrEdit, mode: .inspectorOn, triggers: [.key(key)]) { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor()
            try await VoiceOver.say(step(control, direction, on: track))
        }
    }

    @AccessibilityActor
    static func step(_ control: TrackStrip.PanControl, _ direction: SliderStep, on track: TrackStrip) throws -> String {
        let slider = try track.pan(control)
        try slider.step(direction)
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
