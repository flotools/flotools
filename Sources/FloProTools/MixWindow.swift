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

    // MARK: Solo

    public func soloButton() throws -> AXElement {
        try element.required("the Solo button") { try $0.button("Solo") }
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

    // MARK: Sends

    /// Selector and assignment buttons of send slot 0 (A) to 9 (J). Sends A-E and F-J are two groups of ten buttons, a selector and an assignment per slot.
    public func sendButtons(slot: Int) throws -> (selector: AXElement, assignment: AXElement) {
        let groupName = slot < 5 ? "Sends A-E" : "Sends F-J"
        let buttons = try element.required("the \(groupName) sends") { try $0.group(groupName) }.buttons
        let index = (slot % 5) * 2
        guard buttons.count > index + 1 else { throw FloError.notFound("the send \(Self.sendLetter(slot)) buttons") }
        return (buttons[index], buttons[index + 1])
    }

    public nonisolated static func sendLetter(_ slot: Int) -> String {
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
