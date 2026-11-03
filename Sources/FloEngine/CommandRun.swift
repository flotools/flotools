import FloSystem

/// One run of a command: what started it, the front context at that moment, and the engine. Command bodies get one of these.
/// The run's invocation ID for the log is `Log.invocation`, which tasks started by the run inherit, also across actor hops.
public struct CommandRun: Sendable {
    public enum Trigger: Sendable, Equatable {
        case hotKey(KeyCombo, KeyPhase)
        /// Run by the app, for example from the status menu.
        case direct
        /// Started by something that happened rather than a key, such as a plug-in window coming to front, like Keyboard Maestro's window triggers. Checked like a hotkey run.
        case event(String)
    }

    public let command: Command
    public let trigger: Trigger
    public let context: FrontContext
    public let engine: Engine

    /// Sends the hotkey that started this run on to the front app, for commands that act only in some windows. Does nothing for other triggers.
    @MainActor
    public func passThrough() {
        guard case .hotKey(let combo, .pressed) = trigger else { return }
        engine.passThrough(combo, to: context)
    }
}
