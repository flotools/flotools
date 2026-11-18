import FloSystem

/// The DSP button's label distinguishes these states; its value is "Selected" for all three.
public enum DSPMode: Sendable, Equatable {
    case native, enabled, automaticallyEnabled

    public init(reading label: String) throws {
        switch label {
        case "Native Mode": self = .native
        case "DSP Mode enabled": self = .enabled
        case _ where label.hasPrefix("DSP Mode is automatically enabled because "):
            self = .automaticallyEnabled
        default: throw FloError.unexpectedValue("the DSP mode: \(label)")
        }
    }
}

extension TrackStrip {
    /// Nil when the track does not expose a DSP button, such as a MIDI track or a session without a Hybrid Engine.
    public func dspMode() throws -> DSPMode? {
        try dspButton().map { try dspMode($0) }
    }

    /// Only explicitly enabled DSP is changed. Routing can leave the track in automatic DSP after the press.
    public func toggleDSPMode() async throws -> Bool {
        guard let button = try dspButton() else { return true }
        let before = try dspMode(button)
        guard before == .enabled else { return true }
        try Task.checkCancellation()
        try button.press()
        return try await ProToolsUpdate.reading(changedFrom: before) { try dspMode(button) } != before
    }

    private func dspMode(_ button: AXElement) throws -> DSPMode {
        try DSPMode(reading: button.name.required("the DSP mode of \(name)"))
    }
}
