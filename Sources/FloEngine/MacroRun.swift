import FloSystem

/// One run of a macro: what started it, the front context at that moment, and the engine. Macro bodies get one of these.
/// The run's invocation ID for the log is `Log.invocation`, which tasks started by the run inherit, also across actor hops.
public struct MacroRun: Sendable {
    public enum Trigger: Sendable, Equatable {
        case hotKey(KeyCombo, KeyPhase)
        /// Run by another macro, like Keyboard Maestro's Execute Macro action.
        case nested(by: MacroID)
        /// Run by the app, for example from the status menu.
        case direct
    }

    public let macro: Macro
    public let trigger: Trigger
    public let context: FrontContext
    public let engine: MacroEngine
    /// The macros this run is nested in, outermost first, then this macro. Used to reject cycles.
    let path: [MacroID]

    /// Runs another macro inside this one and waits for it. Errors and cancellation reach this macro.
    public func run(_ id: MacroID) async throws {
        try await engine.runNested(id, from: self)
    }

    /// Sends the hotkey that started this run on to the front app, for macros that act only in some windows. Does nothing for other triggers.
    @MainActor
    public func passThrough() {
        guard case .hotKey(let combo, .pressed) = trigger else { return }
        engine.passThrough(combo)
    }
}
