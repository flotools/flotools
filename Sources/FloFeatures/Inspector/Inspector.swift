import FloEngine
import FloProTools
import FloSystem

/// The Inspector keys work on the track whose name the VoiceOver cursor is on, in the Mix or Edit window. Off a track, the key goes to the next command that has it, or on to Pro Tools.
enum Inspector {
    @MainActor
    static var commands: [Command] { [TrackStrip.SlotKind.insert, .send].flatMap { kind in (0..<10).map { slot(kind, $0) } + (0..<10).map { assign(kind, $0) } } + [
        toggle("inspector.speakToggleSolo", "Speak/Toggle Solo", key: "S", .solo, state: "solo"),
        toggle("inspector.speakToggleMute", "Speak/Toggle Mute", key: "M", .mute, state: "mute"),
        toggle("inspector.speakToggleRecordState", "Speak/Toggle Record State", key: "R", .recordEnable, state: "record arm"),
        toggle("inspector.speakToggleInputMonitor", "Speak/Toggle Input Monitor", key: "K", .inputMonitor, state: "input monitor"),
        toggle("inspector.speakToggleInstrumentMute", "Speak/Toggle Instrument Mute", key: "Opt+M", .instrumentMute, state: "instrument mute"),
        pan("inspector.panRightOnMonoLeftChannel", "Pan Right on Mono/Left Channel", key: "Ctrl+Cmd+Right", .monoOrLeft, .increase, "Moves the pan of a mono track, or the left pan of a stereo track, one step right and speaks it."),
        pan("inspector.panLeftOnMonoLeftChannel", "Pan Left on Mono/Left Channel", key: "Ctrl+Cmd+Left", .monoOrLeft, .decrease, "Moves the pan of a mono track, or the left pan of a stereo track, one step left and speaks it."),
        pan("inspector.panRightOnRightChannel", "Pan Right on Right Channel", key: "Ctrl+Shift+Cmd+Right", .right, .increase, "Moves the right pan of a stereo track, or the pan of a mono track, one step right and speaks it."),
        pan("inspector.panLeftOnRightChannel", "Pan Left on Right Channel", key: "Ctrl+Shift+Cmd+Left", .right, .decrease, "Moves the right pan of a stereo track, or the pan of a mono track, one step left and speaks it."),
        pan("inspector.panInstrumentRight", "Pan Instrument Right", key: "Ctrl+Opt+Right", .instrument, .increase, "Moves the MIDI pan of an instrument track one step right and speaks it."),
        pan("inspector.panInstrumentLeft", "Pan Instrument Left", key: "Ctrl+Opt+Left", .instrument, .decrease, "Moves the MIDI pan of an instrument track one step left and speaks it."),
    ] }

    /// An Inspector command: it works on the track under the VoiceOver cursor.
    @MainActor
    static func command(_ id: CommandID, _ name: String, summary: String, key: String, body: @escaping CommandBody) -> Command {
        Command(id, name, summary: summary, scope: .trackUnderVoiceOverCursor, triggers: [.key(key)], body: body)
    }

    /// An Inspector command that runs again while its key is held, for controls that move one step per run.
    @MainActor
    static func repeatingCommand(_ id: CommandID, _ name: String, summary: String, key: String, body: @escaping CommandBody) -> Command {
        Command.repeatingWhileHeld(id, name, summary: summary, scope: .trackUnderVoiceOverCursor, triggers: [.key(key)], body: body)
    }

    /// An Inspector command with a tap and a hold action.
    @MainActor
    static func command(_ id: CommandID, _ name: String, summary: String, key: String, doneSound: DoneSoundTiming = .beforeHold, tap: @escaping CommandBody, hold: @escaping CommandBody) -> Command {
        Command(id, name, summary: summary, scope: .trackUnderVoiceOverCursor, triggers: [.key(key)], doneSound: doneSound, tap: tap, hold: hold)
    }

    // MARK: Toggles

    /// Tap speaks the toggle's state; hold presses the button and speaks the new state, then plays the done sound, as the JXA played Tink. The JXA waited a fixed 0.1 s before reading (Record State did not wait); this waits until the state changes.
    @MainActor
    static func toggle(_ id: CommandID, _ name: String, key: String, _ toggle: TrackStrip.Toggle, state: String) -> Command {
        Inspector.command(id, name, summary: "Tap speaks the track's \(state) state; hold switches it and speaks the new state.", key: key, doneSound: .afterHold, tap: { run in
            let track = try await run.inspectorTrack()
            try await VoiceOver.say(stateText(toggle, track.state(of: toggle)))
        }, hold: { run in
            let track = try await run.inspectorTrack()
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

    /// Speak/Open Insert A to J on 1 to 0, and Speak/Open Send A to J on Ctrl+1 to Ctrl+0; `slot` counts from 0. Tap speaks the slot and its assignment. Hold clicks the assignment button, then plays the done sound, as the JXA played Tink. The KM names spelled H "h"; here it is "H".
    @MainActor
    static func slot(_ kind: TrackStrip.SlotKind, _ slot: Int) -> Command {
        let letter = TrackStrip.slotLetter(slot)
        let digit = "\((slot + 1) % 10)"
        let key = kind == .send ? "Ctrl+" + digit : digit
        let opens = kind == .insert ? "the plug-in window" : "the send window"
        let summary = "Tap speaks \(kind.rawValue.lowercased()) \(letter): whether it is active, and what is assigned. Hold opens \(opens)."
        return Inspector.command(CommandID("inspector.speakOpen\(kind.rawValue)\(letter)"), "Speak/Open \(kind.rawValue) \(letter)", summary: summary, key: key, doneSound: .afterHold, tap: { run in
            let track = try await run.inspectorTrack()
            try await VoiceOver.say(slotText(kind, slot, in: track))
        }, hold: { run in
            let track = try await run.inspectorTrack()
            try await track.slotButtons(kind, slot: slot).assignment.pressOpeningMenu()
        })
    }

    /// Assign Insert A to J on Cmd+1 to Cmd+0, and Assign Send A to J on Ctrl+Cmd+1 to Ctrl+Cmd+0: clicks the slot's selector button, which opens Pro Tools' assignment menu. Silent, as in the JXA; VoiceOver reads the menu.
    @MainActor
    static func assign(_ kind: TrackStrip.SlotKind, _ slot: Int) -> Command {
        let letter = TrackStrip.slotLetter(slot)
        let key = (kind == .send ? "Ctrl+Cmd+" : "Cmd+") + "\((slot + 1) % 10)"
        return Inspector.command(CommandID("inspector.assign\(kind.rawValue)\(letter)"), "Assign \(kind.rawValue) \(letter)", summary: "Opens the menu to assign \(kind.rawValue.lowercased()) \(letter).", key: key) { run in
            let track = try await run.inspectorTrack()
            try await track.slotButtons(kind, slot: slot).selector.pressOpeningMenu()
        }
    }

    /// What a tap says. Absent names and values are empty, as in the JXA; failed reads throw.
    @AccessibilityActor
    static func slotText(_ kind: TrackStrip.SlotKind, _ slot: Int, in track: TrackStrip) throws -> String {
        slotMessage(kind, try track.slotReading(kind, slot: slot))
    }

    /// Name the slot kind before reading its state and assignment.
    static func slotMessage(_ kind: TrackStrip.SlotKind, _ reading: TrackStrip.SlotReading) -> String {
        kind.rawValue + reading.letter + ". " + reading.state + ": " + reading.assignment
    }

    // MARK: Pan

    /// Moves one pan control a step and speaks its new position.
    @MainActor
    static func pan(_ id: CommandID, _ name: String, key: String, _ control: TrackStrip.PanControl, _ direction: SliderStep, _ summary: String) -> Command {
        Inspector.repeatingCommand(id, name, summary: summary, key: key) { run in
            let track = try await run.inspectorTrack()
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
