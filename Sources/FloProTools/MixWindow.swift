import FloSystem

/// The Mix window: its track strips and the Group List. Everything here messages Pro Tools, so it runs on `AccessibilityActor`.
@AccessibilityActor
public struct MixWindow {
    private let element: AXElement

    init(_ element: AXElement) { self.element = element }

    /// Soloed tracks in window order, by `TrackStrip.isSoloed(trackName:soloValue:)`. Groups without a name or a Solo button, such as the Group List, are skipped. A failed read throws, so a busy Pro Tools is never reported as "no tracks soloed".
    public func soloedTracks() throws -> [TrackStrip] {
        try element.groups.compactMap { group in
            guard let name = try group.name else { return nil }
            let strip = TrackStrip(name: name, element: group)
            return try strip.isSoloed() ? strip : nil
        }
    }

    /// Whether any row of the Group List has its first button named "Active ...", as the JXA checked. No Group List means no active groups.
    public func hasActiveGroups() throws -> Bool {
        guard let rows = try element.table("Group List")?.rows else { return false }
        return try rows.contains { row in
            let cells = try row.children
            guard cells.count > 1, let name = try cells[1].buttons.first?.name else { return false }
            // JXA's `_beginsWith` ignores case.
            return name.lowercased().hasPrefix("active ")
        }
    }
}

/// One track's group in the Mix window, or in the Edit window for the controls only it shows (freeze, timebase, track view, Elastic Audio, track options). The name is the group's `AXTitle`, for example "Kick - Audio Track ".
@AccessibilityActor
public struct TrackStrip {
    public nonisolated let name: String
    private let element: AXElement

    init(name: String, element: AXElement) {
        self.name = name
        self.element = element
    }

    /// The group named `name` among the immediate children of a Mix or Edit window.
    init(named name: String, in window: AXElement, window kind: ProToolsApp.TrackWindow) throws {
        self.init(name: name, element: try window.required("the track \(name) in the \(kind.rawValue) window") { try $0.group(name) })
    }

    /// Folder tracks are unsoloed after the others, as in the JXA.
    public nonisolated var isFolder: Bool { name.contains("Folder Track") }

    // MARK: Toggle buttons

    /// The track buttons that Speak/Toggle macros read and press.
    public enum Toggle: Sendable {
        case solo, mute, recordEnable, inputMonitor
        /// "MIDI Mute" in the Instrument section of an instrument track.
        case instrumentMute
    }

    /// The button for `toggle`. The input monitoring button is named for its state, for example "Input monitoring disabled" or, on an instrument track, "Input monitoring is enabled, but delay compensation is disabled. ..." (seen 2026-11-02); the JXA also handled a button named "TrackInput Monitor" that shows its state as its value.
    public func button(_ toggle: Toggle) throws -> AXElement {
        switch toggle {
        case .solo: try element.required("the Solo button") { try $0.button("Solo") }
        case .mute: try element.required("the Mute button") { try $0.button("Mute") }
        case .recordEnable: try element.required("the Track Record Enable button") { try $0.button("Track Record Enable") }
        case .inputMonitor: try element.required("the input monitoring button") { strip in
            try strip.buttons.first { try $0.name?.contains("Input monitoring") == true } ?? strip.button("TrackInput Monitor")
        }
        case .instrumentMute:
            try element.required("the Instrument section") { try $0.group("Instrument") }.required("the MIDI Mute button") { try $0.button("MIDI Mute") }
        }
    }

    /// The toggle's state as Pro Tools shows it: the name of a named input monitoring button, otherwise the button's value, empty when off.
    public func state(of toggle: Toggle) throws -> String {
        let button = try button(toggle)
        if toggle == .inputMonitor, let name = try button.name, name.contains("Input monitoring") { return name }
        return try button.value ?? ""
    }

    /// Whether the track is soloed now. False without a Solo button.
    public func isSoloed() throws -> Bool {
        guard let solo = try element.button("Solo") else { return false }
        return Self.isSoloed(trackName: name, soloValue: try solo.value ?? "")
    }

    /// The JXA rule: the Solo button value is not empty and not "safe" or "inactive", and the track is not a master track.
    nonisolated static func isSoloed(trackName: String, soloValue: String) -> Bool {
        !trackName.localizedCaseInsensitiveContains(" - Master Track")
            && !soloValue.isEmpty
            && !soloValue.localizedCaseInsensitiveContains("safe")
            && !soloValue.localizedCaseInsensitiveContains("inactive")
    }

    // MARK: Inserts and sends

    /// The two kinds of slot rows in a strip. The raw value is the word Pro Tools uses in group and button names, for example "Inserts A-E" and "Send selector B".
    public enum SlotKind: String, Sendable {
        case insert = "Insert"
        case send = "Send"
    }

    /// Selector and assignment buttons of slot 0 (A) to 9 (J). Slots A-E and F-J are two groups of ten buttons each. Inserts list the five selectors, then the five assignments; sends alternate selector and assignment.
    public func slotButtons(_ kind: SlotKind, slot: Int) throws -> (selector: AXElement, assignment: AXElement) {
        let groupName = "\(kind.rawValue)s \(slot < 5 ? "A-E" : "F-J")"
        let buttons = try element.required("the \(groupName) view") { try $0.group(groupName) }.buttons
        let position = slot % 5
        let (selector, assignment) = switch kind {
        case .insert: (position, position + 5)
        case .send: (position * 2, position * 2 + 1)
        }
        guard buttons.count > max(selector, assignment) else { throw FloError.notFound("the \(kind.rawValue.lowercased()) \(Self.slotLetter(slot)) buttons") }
        return (buttons[selector], buttons[assignment])
    }

    public nonisolated static func slotLetter(_ slot: Int) -> String {
        String(UnicodeScalar(UInt8(ascii: "A") + UInt8(slot)))
    }

    // MARK: Pan

    public enum PanControl: Sendable {
        /// The pan knob of a mono track, or the left one of a stereo track.
        case monoOrLeft
        /// The right pan knob of a stereo track; on a mono track its only knob, as in the JXA.
        case right
        /// The MIDI pan of an instrument track, in its Instrument section.
        case instrument
    }

    /// The slider for `control`.
    public func pan(_ control: PanControl) throws -> AXElement {
        switch control {
        case .monoOrLeft, .right:
            let knobs = try panKnobs()
            let index = control == .right && knobs.count > 1 ? 1 : 0
            guard knobs.count > index else { throw FloError.notFound("the pan knob") }
            return knobs[index]
        case .instrument:
            return try instrumentSection().required("the MIDI pan") { try $0.sliders.first { try $0.name?.contains("MIDI Pan indicator") == true } }
        }
    }

    /// Mono tracks have one "Pan Knob", stereo tracks "Left Pan Knob" and "Right Pan Knob". Tracks without panning, such as a MIDI track, have none.
    public func panKnobs() throws -> [AXElement] {
        try element.sliders.filter { try $0.name?.contains("Pan Knob") == true }
    }

    // MARK: Faders

    public enum Fader: Sendable {
        case volume
        /// The peak hold readout next to the level meter; pressing it clears the hold.
        case peak
        /// The MIDI volume of an instrument track, in its Instrument section.
        case instrumentVolume
    }

    public func fader(_ fader: Fader) throws -> AXElement {
        switch fader {
        case .volume: try element.required("the volume fader") { try $0.child(role: "AXSlider", name: "Volume") }
        case .peak: try element.required("the peak meter") { try $0.child(role: "AXSlider", name: "Peak") }
        case .instrumentVolume: try instrumentSection().required("the MIDI volume") { try $0.sliders.first { try $0.name?.contains("MIDI Volume indicator") == true } }
        }
    }

    // MARK: Meters

    public enum Meter: Sendable {
        /// The track's level meter; empty when there is no signal.
        case level
        /// The gain reduction meter, shown when a dynamics plug-in is inserted, for example "minus 3 db".
        case gainReduction
    }

    /// Both meters are buttons whose role description is "Level Meter"; only the gain reduction one has a title (checked live on the Master track, 2026-11-02). The JXA took the first "Level Meter" button for the level meter, which comes first.
    public func meter(_ meter: Meter) throws -> AXElement {
        switch meter {
        case .level:
            try element.required("the level meter") { try $0.buttons.first { try $0.roleDescription == "Level Meter" && $0.title != "Gain Reduction" } }
        case .gainReduction:
            try element.required("the gain reduction meter") { try $0.button("Gain Reduction") }
        }
    }

    // MARK: Menus and fields

    /// Pop-up buttons, buttons and fields that macros read and press. Names were checked live on 2026-11-02 (Pro Tools 2025); several end in a line break and the current setting, for example "Audio Input Path selector\n\"no input\"".
    public enum Control: Sendable {
        case automationMode, group, input, output, instrumentInput, instrumentOutput, trackName, comments
        /// Edit window only.
        case playlist, timebase, trackView, trackOptions, freeze, elasticAudioPlugIn, elasticAudioSelector
    }

    /// The element for `control`. Matching ignores case, as JXA's `_contains` did. Input and output are the MIDI selectors on a MIDI track and the audio paths on other tracks.
    public func control(_ control: Control) throws -> AXElement {
        let isMIDI = name.contains(" - MIDI Track")
        return switch control {
        case .automationMode: try first("the automation mode selector", role: "AXPopUpButton") { $0.contains("automation mode selector") }
        case .group: try first("the group selector", role: "AXButton") { $0.hasPrefix("group id indicator") }
        case .input where isMIDI: try first("the MIDI input selector", role: "AXButton") { $0.contains("midi input selector") }
        case .input: try first("the input path selector", role: "AXPopUpButton") { $0.contains("input path") }
        case .output where isMIDI: try first("the MIDI output selector", role: "AXButton") { $0.contains("midi output selector") }
        case .output: try first("the output path selector", role: "AXPopUpButton") { $0.contains("output path") }
        case .instrumentInput: try first("the MIDI input selector", role: "AXButton", in: instrumentSection()) { $0.contains("midi input selector") }
        case .instrumentOutput: try first("the MIDI output selector", role: "AXButton", in: instrumentSection()) { $0.contains("midi output selector") }
        case .trackName: try first("the track name button", role: "AXPopUpButton") { $0.contains("track name") }
        case .comments: try first("the comments field", role: "AXTextField") { $0.hasPrefix("comments") }
        case .playlist: try first("the playlist selector", role: "AXPopUpButton") { $0.contains("playlist selector") }
        case .timebase: try first("the timebase selector") { $0.contains("timebase selector") }
        case .trackView: try first("the track view selector") { $0.contains("track view selector") }
        case .trackOptions: try first("the track options button", role: "AXPopUpButton") { $0.contains("track options") }
        case .freeze: try first("the freeze button", role: "AXButton") { $0.contains("frozen") }
        // The JXA looked for "Plug-in"; this Pro Tools says "Plugin", so both spellings match.
        case .elasticAudioPlugIn: try first("the Elastic Audio plug-in") { $0.hasPrefix("current elastic audio or ara plug") }
        case .elasticAudioSelector: try first("the Elastic Audio selector") { $0.contains("elastic audio or ara plug") && $0.contains("selector") }
        }
    }

    private func instrumentSection() throws -> AXElement {
        try element.required("the Instrument section") { try $0.group("Instrument") }
    }

    /// The first child of `parent` (the strip by default) with `role` (any role if nil) whose lowercased name passes `matches`.
    private func first(_ what: String, role: String? = nil, in parent: AXElement? = nil, _ matches: (String) -> Bool) throws -> AXElement {
        try (parent ?? element).required(what) { parent in
            try parent.children.first { child in
                guard let name = try child.name, matches(name.lowercased()) else { return false }
                return try role == nil || child.role == role
            }
        }
    }
}
