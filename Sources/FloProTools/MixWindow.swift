import CoreGraphics
import FloSystem

/// The Mix window: its track strips and the Group List. Everything here messages Pro Tools, so it runs on `AccessibilityActor`.
@AccessibilityActor
public struct MixWindow {
    private let element: AXElement

    init(_ element: AXElement) { self.element = element }

    /// The shown tracks' strips in window order. Hidden tracks have no strip. Groups without a name are skipped.
    public func trackStrips() throws -> [TrackStrip] {
        try element.groups.compactMap { group in
            guard let name = try group.name else { return nil }
            return TrackStrip(name: name, element: group)
        }
    }

    /// The tracks that take part in `flag` and have it (`on`) or not, in window order. A failed read throws, so a busy Pro Tools is never reported as "no tracks soloed".
    public func tracks(_ flag: TrackFlag, on: Bool) throws -> [TrackStrip] {
        try trackStrips().filter { try $0.has(flag) == on }
    }

    /// The strip of the shown track named `name`, or nil when it is gone or hidden.
    public func track(named name: String) throws -> TrackStrip? {
        try element.group(name).map { TrackStrip(name: name, element: $0) }
    }

    /// The Track List table at the left of the window.
    public func trackList() throws -> TrackList {
        TrackList(try element.required("the Track List") { try $0.table("Track List") })
    }

    /// Opens the Track List pop-up menu (show and hide, sort and so on).
    public func openTrackListMenu() throws {
        try element.required("the Track List pop-up") { try $0.button("Track List pop-up") }.pressOpeningMenu()
    }

    /// The Track List can be collapsed to a narrow strip that hides its rows' buttons; this expands it. The Show/Hide button's value is "Expanded. " or contains "Collapsed".
    public func expandTrackList() throws {
        let button = try element.required("the Track List Show/Hide button") { try $0.button("Track List Show/Hide") }
        if try button.value?.contains("Collapsed") == true { try button.press() }
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

    /// Where the track's group is on screen.
    public func frame() throws -> CGRect {
        CGRect(origin: try element.position.required("the position of the track \(name)"), size: try element.size.required("the size of the track \(name)"))
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

    /// The button for `toggle`, or `FloError.notFound`.
    public func button(_ toggle: Toggle) throws -> AXElement {
        try element.required(Self.buttonDescription(toggle)) { _ in try findButton(toggle) }
    }

    private nonisolated static func buttonDescription(_ toggle: Toggle) -> String {
        switch toggle {
        case .solo: "the Solo button"
        case .mute: "the Mute button"
        case .recordEnable: "the Track Record Enable button"
        case .inputMonitor: "the input monitoring button"
        case .instrumentMute: "the MIDI Mute button"
        }
    }

    /// The button for `toggle`, or nil when the track has none. The input monitoring button is named for its state, for example "Input monitoring disabled" or, on an instrument track, "Input monitoring is enabled, but delay compensation is disabled. ..." (seen 2026-11-02); the JXA also handled a button named "TrackInput Monitor" that shows its state as its value.
    private func findButton(_ toggle: Toggle) throws -> AXElement? {
        switch toggle {
        case .solo: try element.button("Solo")
        case .mute: try element.button("Mute")
        case .recordEnable: try element.button("Track Record Enable")
        case .inputMonitor: try element.buttons.first { try $0.name?.contains("Input monitoring") == true } ?? element.button("TrackInput Monitor")
        case .instrumentMute:
            try element.required("the Instrument section") { try $0.group("Instrument") }.button("MIDI Mute")
        }
    }

    /// The toggle's state as Pro Tools shows it: the name of a named input monitoring button, otherwise the button's value, empty when off.
    public func state(of toggle: Toggle) throws -> String {
        try Self.state(of: toggle, button: button(toggle))
    }

    private static func state(of toggle: Toggle, button: AXElement) throws -> String {
        if toggle == .inputMonitor, let name = try button.name, name.contains("Input monitoring") { return name }
        return try button.value ?? ""
    }

    /// Whether the track has `flag` now, by `TrackFlag.state(of:trackName:buttonState:)`; nil when it does not take part, including when it lacks the button.
    public func has(_ flag: TrackFlag) throws -> Bool? {
        guard let button = try findButton(flag.toggle) else { return nil }
        return TrackFlag.state(of: flag, trackName: name, buttonState: try Self.state(of: flag.toggle, button: button))
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

    /// The peak hold level in dB, for example -3.1 for "minus 3.1"; nil for "minus ∞" and for a track without a peak meter.
    public func peakDecibels() throws -> Double? {
        guard let peak = try element.child(role: "AXSlider", name: "Peak"), let text = try peak.valueDescription else { return nil }
        return Self.decibels(peakText: text)
    }

    nonisolated static func decibels(peakText text: String) -> Double? {
        let number = text.hasPrefix("minus ") ? "-" + text.dropFirst("minus ".count) : text
        return Double(number).flatMap { $0.isFinite ? $0 : nil }
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
