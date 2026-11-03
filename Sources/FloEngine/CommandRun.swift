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

    /// Sends the hotkey that started this run on to the front app, and returns once it is posted, so what the command does next follows the key. Does nothing for other triggers. Throws `FloError.couldNot` when the key cannot be sent.
    public func passThrough() async throws {
        guard case .hotKey(let combo, .pressed) = trigger else { return }
        guard context.processID > 0 else { throw FloError.couldNot("send a key to Pro Tools") }
        try await Keyboard.press(combo, pid: context.processID)
    }
}
