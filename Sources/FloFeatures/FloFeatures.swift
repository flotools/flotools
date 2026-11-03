import FloEngine
import FloProTools
import FloSystem

/// All commands. Each feature folder declares its own.
public enum FloFeatures {
    /// All commands. `session` is what they remember about the Pro Tools session; `openPreferences` shows the app's preferences panel.
    @MainActor
    public static func all(session: SessionState = SessionState(), openPreferences: @escaping @MainActor @Sendable () -> Void = {}) -> [Command] {
        Inspector.commands + InspectorControls.commands + InspectorMeters.commands(session.gainReduction) + SettingToggles.commands + Counters.commands + InspectorMode.commands + TrackStatus.commands + TrackLists.commands + FadeDialogs.commands + SelectedTab.commands + PlugIns.commands(session.plugInView) + AudioSuite.commands + KeyAnnouncements.commands + MidiEvents.commands(session.eventColumn) + WindowTools.commands + ClipDrag.commands(session.clipMark) + PreferenceCommands.commands(openPreferences: openPreferences)
    }

    /// Applies what the preferences control, like the KM Refresh Preference macro: the double-press timeout and whether Toggle Temporary Inspector works. Called at launch and after the preferences panel saves.
    @MainActor
    public static func apply(_ preferences: Preferences, to engine: Engine) {
        engine.doublePressTimeout = .milliseconds(preferences.timeout)
        InspectorMode.apply(preferences, to: engine)
    }

    /// Sets the start state that the KM version set on Pro Tools launch. `Lifecycle` calls it when Flo Tools starts and when Pro Tools launches.
    @MainActor
    static func setStartState(_ preferences: Preferences, in engine: Engine) {
        InspectorMode.applyStartState(preferences, to: engine)
    }

    /// An engine with all commands installed, using the app's hotkeys and context monitor.
    @MainActor
    public static func makeEngine(session: SessionState, hotKeys: HotKeyCenter, contextMonitor: ContextMonitor, openPreferences: @escaping @MainActor @Sendable () -> Void) -> Engine {
        makeEngine(commands: all(session: session, openPreferences: openPreferences), hotKeys: hotKeys, contextMonitor: contextMonitor)
    }

    /// An engine with the given commands. Tests never start it, so the default hotkeys and monitor stay unused.
    @MainActor
    static func makeEngine(commands: [Command] = all(), hotKeys: HotKeyCenter = HotKeyCenter(), contextMonitor: ContextMonitor = ContextMonitor()) -> Engine {
        let engine = Engine(hotKeys: hotKeys, contextMonitor: contextMonitor)
        commands.forEach(engine.install)
        return engine
    }
}
