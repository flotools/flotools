import FloSystem

/// The Mix window: its track strips and the Group List. Everything here messages Pro Tools, so it runs on `AccessibilityActor`.
@AccessibilityActor
public struct MixWindow {
    private let element: AXElement

    init(_ element: AXElement) { self.element = element }

    /// The strip with this name, for example "Kick - Audio Track ".
    public func strip(named name: String) throws -> TrackStrip {
        TrackStrip(name: name, element: try element.required("the track \(name) in the Mix window") { try $0.group(name) })
    }

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

/// One track strip in the Mix window. The name is the strip's `AXTitle`, for example "Kick - Audio Track ".
@AccessibilityActor
public struct TrackStrip {
    public nonisolated let name: String
    private let element: AXElement

    init(name: String, element: AXElement) {
        self.name = name
        self.element = element
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

    /// The slider for `control`. Mono tracks have one "Pan Knob", stereo tracks "Left Pan Knob" and "Right Pan Knob".
    public func pan(_ control: PanControl) throws -> AXElement {
        switch control {
        case .monoOrLeft, .right:
            let knobs = try element.sliders.filter { try $0.name?.contains("Pan Knob") == true }
            let index = control == .right && knobs.count > 1 ? 1 : 0
            guard knobs.count > index else { throw FloError.notFound("the pan knob") }
            return knobs[index]
        case .instrument:
            let instrument = try element.required("the Instrument section") { try $0.group("Instrument") }
            return try instrument.required("the MIDI pan") { try $0.sliders.first { try $0.name?.contains("MIDI Pan indicator") == true } }
        }
    }
}
