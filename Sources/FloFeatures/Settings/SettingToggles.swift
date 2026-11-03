import FloEngine
import FloProTools
import FloSystem

/// Flo Tools commands that speak and switch an on/off Pro Tools setting: edit modes, MIDI and cursor tool buttons of the Edit window, and checked items of the Options and View menus. One table, three behaviors.
enum SettingToggles {
    /// What is spoken for each state, as in the JXA.
    struct Wording: Sendable {
        let on: String
        let off: String
    }

    @MainActor
    static var commands: [Command] { [
        button("floTools.speakSelectShuffleMode", "Speak/Select Shuffle Mode", key: "F1", .editMode, "EditModeShuffle", Wording(on: "Shuffle Mode, On", off: "Shuffle Mode, Off")),
        button("floTools.speakSelectSlipMode", "Speak/Select Slip Mode", key: "F2", .editMode, "EditModeSlip", Wording(on: "Slip Mode, On", off: "Slip Mode, Off")),
        button("floTools.speakSelectSpotMode", "Speak/Select Spot Mode", key: "F3", .editMode, "EditModeSpot", Wording(on: "Spot Mode, On", off: "Spot Mode, Off")),
        button("floTools.speakToggleConductor", "Speak/Toggle Conductor", key: "Opt+F12", .midi, "Conductor Track", Wording(on: "Conductor On", off: "Conductor off")),
        button("floTools.speakToggleCountIn", "Speak/Toggle Count In", key: "Opt+Keypad 8", .midi, "Count in toggle", Wording(on: "Countin On", off: "Countin off")),
        button("floTools.speakToggleMetronome", "Speak/Toggle Metronome", key: "Opt+Keypad 7", .midi, "Metronome", Wording(on: "Metronome On", off: "Metronome off")),
        button("floTools.speakToggleMidiMerge", "Speak/Toggle Midi Merge", key: "Opt+Keypad 9", .midi, "MIDI Merge", Wording(on: "Midi merge On", off: "Midi merge off")),
        button("floTools.speakToggleWaitForNote", "Speak/Toggle Wait for Note", key: "Opt+F11", .midi, "Wait for Note", Wording(on: "Wait for note On", off: "Wait for note off")),
        button("floTools.speakToggleInsertionFollowsPlayback", "Speak/Toggle Insertion Follows Playback", key: "Ctrl+N", .cursorTool, "Insertion Follows Playback", Wording(on: "Insertion Follows Playback, On", off: "Insertion Follows Playback, Off")),
        button("floTools.speakToggleTabToTransients", "Speak/Toggle Tab to Transients", key: "Opt+Cmd+Tab", .cursorTool, "Tab to Transients", Wording(on: "Tab to Transients, On", off: "Tab to Transients, Off")),
        toggle("floTools.speakToggleGridMode", "Speak/Toggle Grid Mode", key: "F4", .editWindowButton(.editMode, .contains("Grid")), spoken: gridModeText),
        menuItem("floTools.speakToggleDynamicTransport", "Speak/Toggle Dynamic Transport", key: "Ctrl+Cmd+P", "Options", "Dynamic Transport", Wording(on: "Dynamic Transport, Checked", off: "Dynamic Transport")),
        menuItem("floTools.speakToggleLoopPlayback", "Speak/Toggle Loop Playback", key: "Shift+Cmd+L", "Options", "Loop Playback", Wording(on: "Loop Playback , Checked", off: "Loop Playback")),
        menuItem("floTools.speakToggleLoopRecord", "Speak/Toggle Loop Record", key: "Opt+L", "Options", "Loop Record", Wording(on: "Loop Record , Checked", off: "Loop Record")),
        menuItem("floTools.speakTogglePrePostRoll", "Speak/Toggle Pre/Post Roll", key: "Cmd+K", "Options", "Pre/Post-Roll", Wording(on: "Pre/Post Roll, Checked", off: "Pre/Post Roll")),
        menuItem("floTools.speakToggleQuickPunch", "Speak/Toggle Quick Punch", key: "Shift+Cmd+P", "Options", "QuickPunch", Wording(on: "Quick Punch, Checked", off: "Quick Punch")),
        menuItem("floTools.speakToggleTrackPunch", "Speak/Toggle Track Punch", key: "Shift+Cmd+T", "Options", "TrackPunch", Wording(on: "Track Punch, Checked", off: "Track Punch")),
        menuItem("floTools.speakToggleTransportOnline", "Speak/Toggle Transport Online", key: "Cmd+J", "Options", "Transport Online", Wording(on: "Transport Online, Checked", off: "Transport Online")),
        menuItem("floTools.speakToggleNarrowMix", "Speak/Toggle Narrow Mix", key: "Opt+Cmd+M", "View", "Narrow Mix", Wording(on: "Narrow Mix, Checked", off: "Narrow Mix")),
        link("floTools.toggleAndSpeakLinkTimelineAndEditSelection", "Toggle And Speak Link Timeline And Edit Selection", key: "Shift+/", "Link Timeline and Edit Selection", Wording(on: "Timeline and Edit Selection Linked", off: "Timeline and Edit Selection Unlinked")),
        link("floTools.toggleAndSpeakLinkTrackAndEditSelection", "Toggle And Speak Link Track and Edit Selection", key: "Shift+T", "Link Track and Edit Selection", Wording(on: "Track and Edit Selection Linked", off: "Track and Edit Selection Unlinked")),
        toggleInputMonitor,
    ] }

    @MainActor
    private static func button(_ id: CommandID, _ name: String, key: String, _ cluster: EditWindowControl.Cluster, _ button: String, _ wording: Wording) -> Command {
        toggle(id, name, key: key, .editWindowButton(cluster, .is(button))) { control in try wording.text(control.isOn) }
    }

    @MainActor
    private static func menuItem(_ id: CommandID, _ name: String, key: String, _ menu: String, _ item: String, _ wording: Wording) -> Command {
        toggle(id, name, key: key, .menuItem(menu: menu, .is(item))) { control in try wording.text(control.isOn) }
    }

    /// Single press speaks the setting; double press plays the done sound, switches it and speaks the new state. The JXA waited a fixed 0.1 s before reading the new state of a button and spoke nothing after choosing a menu item; this waits until the state changes, and speaks menu items too, so every double press confirms what it did. A dimmed control is refused: Pro Tools ignores the press, and speaking the unchanged state would sound like success. Pro Tools dims its menus while a modal window such as the About splash is open.
    @MainActor
    private static func toggle(_ id: CommandID, _ name: String, key: String, _ setting: ProToolsSetting, spoken: @escaping @Sendable @AccessibilityActor (SettingControl) throws -> String) -> Command {
        Command(id, name, scope: .anyProToolsWindow, triggers: [.key(key)], single: { _ in
            let control = try await ProToolsApp.running().control(setting)
            try await VoiceOver.say(spoken(control))
        }, double: { _ in
            let control = try await ProToolsApp.running().control(setting)
            guard try await control.isEnabled else {
                let name = try await control.name
                throw FloError.couldNot("switch \(name), it is dimmed")
            }
            try await VoiceOver.say(ProToolsUpdate.reading(after: { try control.press() }) { try spoken(control) })
        })
    }

    /// The Grid mode button is named for the grid kind, such as "Absolute Grid mode", which the JXA spoke as "Grid mode, Absolute ".
    @AccessibilityActor
    static func gridModeText(_ control: SettingControl) throws -> String {
        try gridModeText(isOn: control.isOn, buttonName: control.name)
    }

    static func gridModeText(isOn: Bool, buttonName: String) -> String {
        isOn ? "Grid mode, " + SettingControl.gridKind(buttonName: buttonName) : "Grid mode, off"
    }

    /// The hotkey is Pro Tools' own shortcut for the Options menu item, so it goes on to Pro Tools, which switches the setting, and the new state is spoken if the guard allows it, as in the KM version. The wait is longer than `ProToolsUpdate.timeout` because the key travels through the event system first.
    @MainActor
    private static func link(_ id: CommandID, _ name: String, key: String, _ item: String, _ wording: Wording) -> Command {
        let setting = ProToolsSetting.menuItem(menu: "Options", .is(item))
        return Command(id, name, scope: .anyProToolsWindow, triggers: [.key(key)]) { run in
            try await KeyAnnouncements.announceChange(run, when: .outsideListedDialogsAndText, within: .milliseconds(500), find: { try ProToolsApp.running().control(setting) }, read: { try wording.text($0.isOn) })
        }
    }

    /// Toggle Input Monitor (Opt+K): chooses Track > Set Record Tracks to Input Only or Auto Input, whichever Pro Tools offers, and speaks the mode it switched to. The item names the other mode, so after the switch it names the mode that was left.
    @MainActor
    static var toggleInputMonitor: Command {
        let setting = ProToolsSetting.menuItem(menu: "Track", .contains("Set Record Tracks to"))
        return Command("floTools.toggleInputMonitor", "Toggle Input Monitor", scope: .anyProToolsWindow, triggers: [.key("Opt+K")]) { _ in
            let control = try await ProToolsApp.running().control(setting)
            guard try await control.isEnabled else {
                try await VoiceOver.say("Set Record Tracks to is Dimmed")
                return
            }
            let after = try await ProToolsUpdate.reading(after: { try control.press() }) { try control.name }
            try await VoiceOver.say(inputMonitorText(itemName: after))
        }
    }

    static func inputMonitorText(itemName: String) -> String {
        switch SettingControl.inputMonitorMode(itemName: itemName) {
        case .inputOnly: "Input Only"
        case .autoInput: "Auto Input"
        }
    }
}

extension SettingToggles.Wording {
    func text(_ isOn: Bool) -> String { isOn ? on : off }
}
