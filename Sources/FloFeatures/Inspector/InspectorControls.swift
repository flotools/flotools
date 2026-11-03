import FloEngine
import FloProTools
import FloSystem

/// Inspector commands for a track's menus, faders, comments and freeze state. Each works on the track under the VoiceOver cursor, in the Mix window unless the control is only in the Edit window, as in the JXA.
enum InspectorControls {
    @MainActor
    static var commands: [Command] { [
        menu("inspector.speakSelectAutomationMode", "Speak/Select Automation Mode", key: "A", .mix, .automationMode, "Single press speaks the track's automation mode; double press opens its menu."),
        menu("inspector.speakSelectGroup", "Speak/Select Group", key: "G", .mix, .group, "Single press speaks the track's group, or \"No Group\"; double press opens the group menu."),
        menu("inspector.speakSelectTrackInput", "Speak/Select Track Input", key: "I", .mix, .input, "Single press speaks the track's input; double press opens its menu."),
        menu("inspector.speakSelectTrackOutput", "Speak/Select Track Output", key: "O", .mix, .output, "Single press speaks the track's output; double press opens its menu."),
        menu("inspector.speakSelectInstrumentInput", "Speak/Select Instrument Input", key: "Opt+I", .mix, .instrumentInput, "Single press speaks the track's instrument input; double press opens its menu."),
        menu("inspector.speakSelectInstrumentOutput", "Speak/Select Instrument Output", key: "Opt+O", .mix, .instrumentOutput, "Single press speaks the track's instrument output; double press opens its menu."),
        // The JXA spoke the track name from the Mix window and opened the playlist selector in the Edit window, which is the only one that has it.
        menu("inspector.speakSelectPlaylist", "Speak/Select Playlist", key: "\\", .mix, .trackName, opening: (.edit, .playlist), "Single press speaks the track name, which is its playlist's name; double press opens the playlist menu in the Edit window."),
        menu("inspector.speakSelectTimebase", "Speak/Select Timebase", key: "B", .edit, .timebase, "Single press speaks the track's timebase; double press opens its menu."),
        menu("inspector.speakSelectTrackView", "Speak/Select Track View", key: "W", .edit, .trackView, "Single press speaks the track's track view; double press opens its menu."),
        menu("inspector.speakSelectElasticAudioPlugin", "Speak/Select Elastic Audio Plugin", key: "E", .edit, .elasticAudioPlugIn, opening: (.edit, .elasticAudioSelector), "Single press speaks the track's Elastic Audio plug-in, or \"None\"; double press opens the Elastic Audio menu."),
        menu("inspector.trackOptionsMenu", "Track Options Menu", key: "H", .edit, .trackOptions, "Single press speaks the track options button; double press opens the track options menu."),
        selectTrack,
        comments,
        freeze,
        fader("inspector.speakResetVolumeFader", "Speak/Reset Volume Fader", key: "V", .volume, "Single press speaks the track's volume; double press resets it to 0 dB."),
        fader("inspector.speakResetInstrumentVolume", "Speak/Reset Instrument Volume", key: "Opt+V", .instrumentVolume, "Single press speaks the instrument track's MIDI volume; double press resets it."),
        fader("inspector.speakResetPeakMeter", "Speak/Reset Peak Meter", key: "P", .peak, "Single press speaks the track's peak hold; double press clears it."),
        resetPan,
        resetInstrumentPan,
        volumeStep("inspector.increaseVolume", "Increase Volume", key: "Ctrl+Cmd+Up", .volume, .increase, "Moves the volume fader one step up and speaks it."),
        volumeStep("inspector.decreaseVolume", "Decrease Volume", key: "Ctrl+Cmd+Down", .volume, .decrease, "Moves the volume fader one step down and speaks it."),
        volumeStep("inspector.increaseInstrumentVolume", "Increase Instrument Volume", key: "Ctrl+Opt+Up", .instrumentVolume, .increase, "Moves the instrument track's MIDI volume one step up and speaks it."),
        volumeStep("inspector.decreaseInstrumentVolume", "Decrease Instrument Volume", key: "Ctrl+Opt+Down", .instrumentVolume, .decrease, "Moves the instrument track's MIDI volume one step down and speaks it."),
    ] }

    typealias Place = (window: ProToolsApp.TrackWindow, control: TrackStrip.Control)

    // MARK: Menus

    /// Single press speaks the control's `spokenText`. Double press presses the control in `opening` (the same control by default), which opens its Pro Tools menu; VoiceOver reads the menu, so there is no done sound, as in the JXA.
    @MainActor
    static func menu(_ id: CommandID, _ name: String, key: String, _ window: ProToolsApp.TrackWindow, _ control: TrackStrip.Control, opening: Place? = nil, _ summary: String) -> Command {
        let open = opening ?? (window, control)
        return Inspector.command(id, name, summary: summary, key: key, doneSound: .none, single: { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor(in: window)
            try await VoiceOver.say(readout(control, of: track))
        }, double: { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor(in: open.window)
            try await track.control(open.control).pressOpeningMenu()
        })
    }

    @AccessibilityActor
    static func readout(_ control: TrackStrip.Control, of track: TrackStrip) throws -> String {
        let element = try track.control(control)
        return spokenText(control, name: try element.name ?? "", value: try element.value ?? "")
    }

    /// What a single press says for a control, from its name and value: the setting it shows (`TrackStrip.shownSetting`), with words for an empty group, Elastic Audio plug-in or comment, as in the JXA.
    static func spokenText(_ control: TrackStrip.Control, name: String, value: String) -> String {
        let shown = TrackStrip.shownSetting(control, name: name, value: value)
        return switch control {
        case .group: shown.orIfEmpty("No Group")
        case .elasticAudioPlugIn: shown.orIfEmpty("None")
        case .comments: shown.orIfEmpty("No Comment")
        default: shown
        }
    }

    /// Speak And Select Track/Show Right-Click Menu: single press presses the track name button, which selects the track, and says so; double press opens the track name's context menu. No done sound, as in the JXA.
    @MainActor
    static var selectTrack: Command {
        Inspector.command("inspector.speakAndSelectTrackShowRightClickMenu", "Speak And Select Track/Show Right-Click Menu", summary: "Single press selects the track and says so; double press opens the track name's right-click menu.", key: "T", doneSound: .none, single: { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor()
            let name = try await selectTrack(track)
            try await VoiceOver.say(name + " selected")
        }, double: { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor()
            try await track.control(.trackName).showMenu()
        })
    }

    @AccessibilityActor
    private static func selectTrack(_ track: TrackStrip) throws -> String {
        let button = try track.control(.trackName)
        let text = spokenText(.trackName, name: try button.name ?? "", value: "")
        try button.press()
        return text
    }

    /// Speak/Edit Comments: single press speaks the comment or "No Comment"; double press clicks the comments field so it can be typed into, then plays the done sound, as in the JXA.
    @MainActor
    static var comments: Command {
        Inspector.command("inspector.speakEditComments", "Speak/Edit Comments", summary: "Single press speaks the track's comment, or \"No Comment\"; double press puts the cursor in the comments field for typing.", key: "C", doneSound: .afterDouble, single: { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor()
            try await VoiceOver.say(readout(.comments, of: track))
        }, double: { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor()
            try await track.control(.comments).press()
        })
    }

    // MARK: Freeze

    /// Freezing renders the track, which can take a while, so the wait has no short limit. Pro Tools may not answer Accessibility while it works.
    static let freezeTimeout: Duration = .seconds(600)

    /// Speak/Toggle Freeze Status: single press speaks the freeze button's name, such as "Not Frozen". Double press presses it, plays the done sound, then plays the progress sound until the name changes and speaks the new name. The JXA waited without a limit and played Pop every 0.1 s; this plays it once a second, like Unsolo All, and gives up after `freezeTimeout`, because every other command waits in the queue meanwhile.
    @MainActor
    static var freeze: Command {
        Inspector.command("inspector.speakToggleFreezeStatus", "Speak/Toggle Freeze Status", summary: "Single press speaks whether the track is frozen. Double press freezes or unfreezes it, plays a progress sound while Pro Tools works, and speaks the new state.", key: "F", doneSound: .none, single: { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor(in: .edit)
            try await VoiceOver.say(readout(.freeze, of: track))
        }, double: { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor(in: .edit)
            let before = try await toggleFreeze(track)
            await Sound.done.play()
            let after = try await waitForFreeze(track, changedFrom: before)
            try await VoiceOver.say(after)
        })
    }

    /// Presses the freeze button and returns its name from before.
    @AccessibilityActor
    private static func toggleFreeze(_ track: TrackStrip) throws -> String {
        let button = try track.control(.freeze)
        let name = try button.name ?? ""
        try button.press()
        return name
    }

    /// Reads the freeze button's name until it differs from `before`. Pro Tools answers slowly or not at all while it renders, so a busy read (`cannotComplete`, which includes the messaging timeout) only means "not yet". Any other failure, such as a track that is gone, ends the wait rather than holding the queue for `freezeTimeout`.
    private static func waitForFreeze(_ track: TrackStrip, changedFrom before: String) async throws -> String {
        let start = ContinuousClock.now
        var progress = ProgressTicker(startingAt: start)
        var streak = ReadFailureStreak(reading: "the freeze button")
        while true {
            do {
                let name = try await readout(.freeze, of: track)
                streak.succeeded()
                if name != before { return name }
            } catch let error as FloError where error.isBusyApp {
                streak.failed(error)
            }
            guard ContinuousClock.now - start < freezeTimeout else { throw FloError.couldNot("see the freeze finish") }
            await progress.tick()
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    // MARK: Faders and pan

    /// Speak/Reset commands for one slider: single press speaks its value; double press clicks it, which resets it in Pro Tools (unity gain, peak hold cleared), speaks the new value and plays the done sound, as in the JXA.
    @MainActor
    static func fader(_ id: CommandID, _ name: String, key: String, _ fader: TrackStrip.Fader, _ summary: String) -> Command {
        sliderReset(id, name, summary, key: key, .value) { track in [try track.fader(fader)] }
    }

    /// Speak/Reset Pan: every pan knob of the track, "Centered. " on a mono track and two values on a stereo one.
    @MainActor
    static var resetPan: Command {
        sliderReset("inspector.speakResetPan", "Speak/Reset Pan", "Single press speaks the position of each of the track's pan knobs; double press centers them.", key: "N", .panList) { track in try track.panKnobs() }
    }

    /// Speak/Reset Instrument Pan: the MIDI pan of an instrument track, spoken without the ". " that Speak/Reset Pan puts after each knob, as in the JXA.
    @MainActor
    static var resetInstrumentPan: Command {
        sliderReset("inspector.speakResetInstrumentPan", "Speak/Reset Instrument Pan", "Single press speaks the instrument track's MIDI pan; double press centers it.", key: "Opt+N", .value) { track in [try track.pan(.instrument)] }
    }

    /// How Speak/Reset speaks its sliders' values.
    enum SliderReadout: Sendable {
        /// The one slider's value.
        case value
        /// Each value followed by ". ", with "No Pan" for an empty one on a single press, as in the JXA's Speak/Reset Pan.
        case panList
    }

    /// The shared Speak/Reset body.
    @MainActor
    private static func sliderReset(_ id: CommandID, _ name: String, _ summary: String, key: String, _ readout: SliderReadout, sliders: @escaping @AccessibilityActor @Sendable (TrackStrip) throws -> [AXElement]) -> Command {
        let isPan = readout == .panList
        return Inspector.command(id, name, summary: summary, key: key, doneSound: .afterDouble, single: { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor()
            let values = try await values(of: sliders(track))
            try await VoiceOver.say(isPan ? panList(values.map { $0.orIfEmpty("No Pan") }) : values.joined())
        }, double: { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor()
            var values: [String] = []
            for slider in try await sliders(track) {
                values.append(try await reset(slider))
            }
            try await VoiceOver.say(isPan ? panList(values) : values.joined())
        })
    }

    @AccessibilityActor
    private static func values(of sliders: [AXElement]) throws -> [String] {
        try sliders.map { try $0.valueDescription ?? "" }
    }

    /// Clicks a slider and returns its value once Pro Tools shows the change. The JXA waited a fixed 0.1 s.
    @AccessibilityActor
    private static func reset(_ slider: AXElement) async throws -> String {
        try await ProToolsUpdate.reading(after: { try slider.press() }) { try slider.valueDescription ?? "" }
    }

    /// Same text as the JXA version, for example "100 to the left. 100 to the right. ".
    static func panList(_ values: [String]) -> String {
        SpokenList.sentences(values)
    }

    /// Increase and Decrease Volume and Instrument Volume: moves the fader one step and speaks its value, as in the JXA.
    @MainActor
    static func volumeStep(_ id: CommandID, _ name: String, key: String, _ fader: TrackStrip.Fader, _ step: SliderStep, _ summary: String) -> Command {
        Inspector.command(id, name, summary: summary, key: key) { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor()
            try await VoiceOver.say(move(fader, step, on: track))
        }
    }

    @AccessibilityActor
    private static func move(_ fader: TrackStrip.Fader, _ step: SliderStep, on track: TrackStrip) throws -> String {
        let slider = try track.fader(fader)
        try slider.step(step)
        return try slider.valueDescription ?? ""
    }
}

extension String {
    /// `replacement` when the string is empty, like the JXA's `if (value == "") value = "None"`.
    func orIfEmpty(_ replacement: String) -> String { isEmpty ? replacement : self }
}
