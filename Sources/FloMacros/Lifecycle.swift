import FloEngine
import FloProTools
import FloSystem

/// What Flo Tools does on events rather than hotkeys: VoiceOver turning on and off, Pro Tools launching and quitting, and Pro Tools window changes.
///
/// In the KM version these were macros: Auto Toggle Flo Tools, Enable and Disable Flo Tools, Bypass Flo Tools in Keyboard Shortcuts window, Cancel Macros, Cleanup Variables, the launch duties of Check for Automatic Update (its update check is dropped), Refresh Preference, Deactivate Level and Gain Reduction Monitors, and the window trigger of Load Plugin Parameters for Default View. Here they are one policy, because they change Flo Tools itself rather than act in Pro Tools, and they must work while Flo Tools is suspended.
///
/// Owned by the main actor. The app creates one and calls `start()` before starting the engine.
@MainActor
public final class Lifecycle {
    /// Set while VoiceOver is off, so Flo Tools' keys go to Pro Tools. Replaces KM Auto Toggle Flo Tools.
    static let voiceOverOff = Suspension("VoiceOver is not running")
    /// Set while Pro Tools' Keyboard Shortcuts window is open, so the user can type any shortcut into it. As in KM, it holds while the window stays open behind another one.
    static let keyboardShortcuts = Suspension("the Pro Tools Keyboard Shortcuts window is open")
    static let keyboardShortcutsTitle = "Keyboard Shortcuts"
    /// Spoken by the system voice, as in the KM Check for Automatic Update macro.
    static let cannotControlVoiceOver = "Alert! Flo Tools cannot control VoiceOver. Please allow VoiceOver to be controlled with AppleScript in Voiceover Utility."

    private let engine: MacroEngine
    private let session: SessionState
    private let workspace: WorkspaceEvents
    private let preferences: @MainActor () -> Preferences
    /// The last Pro Tools window title, so a change of window can stop the meter watches.
    private var lastProToolsTitle: String?
    /// Numbers the checks for a still open Keyboard Shortcuts window, so only the latest result counts.
    private var shortcutsCheck = 0

    public init(engine: MacroEngine, session: SessionState, workspace: WorkspaceEvents, preferences: @escaping @MainActor () -> Preferences) {
        self.engine = engine
        self.session = session
        self.workspace = workspace
        self.preferences = preferences
    }

    /// Applies the preferences and start state and begins following VoiceOver, Pro Tools and the front window.
    public func start() {
        workspace.onChange = { [weak self] change in self?.handle(change) }
        engine.onContextChange = { [weak self] context in self?.contextChanged(context) }
        workspace.start()
        applyPreferences()
        voiceOverChanged(running: WorkspaceEvents.isVoiceOverRunning)
    }

    public func stop() {
        workspace.stop()
        engine.onContextChange = nil
    }

    /// Applies what the preferences control and the start state, like KM Refresh Preference and the Inspector step of Check for Automatic Update. At Flo Tools start and Pro Tools launch.
    private func applyPreferences() {
        FloMacros.apply(preferences(), to: engine)
        FloMacros.setStartState(preferences(), in: engine)
    }

    /// Speaks `text` and, if VoiceOver is on but does not take it, warns through the system voice that Flo Tools cannot control VoiceOver. An empty text only checks, as the KM version did with `vo.output("")`.
    public func checkVoiceOver(saying text: String) {
        guard WorkspaceEvents.isVoiceOverRunning else {
            Log.info(.voiceover, "VoiceOver is off, not checking that Flo Tools can control it")
            return
        }
        do {
            try VoiceOver.say(text)
        } catch {
            Log.warning(.voiceover, "Flo Tools cannot control VoiceOver: \(error)")
            SystemSpeech.say(Self.cannotControlVoiceOver)
        }
    }

    // MARK: Events

    private func handle(_ change: WorkspaceEvents.Change) {
        switch change {
        case .voiceOver(let running):
            voiceOverChanged(running: running)
        case .launched(bundleID: ProToolsApp.bundleID):
            Log.info(.app, "Pro Tools launched")
            checkVoiceOver(saying: "")
            applyPreferences()
        case .quit(bundleID: ProToolsApp.bundleID):
            // Like KM Cancel Macros and Cleanup Variables: nothing that was going on in Pro Tools can go on, and nothing remembered about its session applies to the next. KM also cleaned up on launch because its variables outlived the engine; here they start empty with Flo Tools.
            Log.info(.app, "Pro Tools quit")
            engine.cancelAll()
            Task { [session] in await session.reset() }
            engine.resume(Self.keyboardShortcuts)
            lastProToolsTitle = nil
        case .launched, .quit:
            break
        }
    }

    private func voiceOverChanged(running: Bool) {
        if running {
            engine.resume(Self.voiceOverOff)
        } else {
            engine.suspend(Self.voiceOverOff)
        }
    }

    private func contextChanged(_ context: FrontContext) {
        guard context.bundleID == ProToolsApp.bundleID else {
            if engine.suspensions.contains(Self.keyboardShortcuts) { resumeIfShortcutsWindowClosed() }
            return
        }
        // Nil while the title of a newly front Pro Tools is still being read.
        guard let title = context.windowTitle else { return }
        if title == Self.keyboardShortcutsTitle {
            engine.suspend(Self.keyboardShortcuts)
        } else if engine.suspensions.contains(Self.keyboardShortcuts) {
            resumeIfShortcutsWindowClosed()
        }
        if let last = lastProToolsTitle, last != title {
            InspectorMeters.stopWatches(in: engine)
        }
        // Like KM Load Plugin Parameters for Default View on a focused window change. A plug-in window showing another plug-in changes its title, which loads that plug-in's view too.
        if title != lastProToolsTitle, title.hasPrefix(PlugInWindow.Kind.plugIn.titlePrefix) {
            engine.fire(PlugIns.loadDefaultView, on: "plug-in window \"\(title)\" in front")
        }
        lastProToolsTitle = title
    }

    /// Resumes once Pro Tools has no Keyboard Shortcuts window. A failed read keeps the suspension; the next window change checks again.
    private func resumeIfShortcutsWindowClosed() {
        shortcutsCheck += 1
        let number = shortcutsCheck
        Task { @MainActor in
            let open: Bool
            do {
                open = try await ProToolsApp.running().hasWindow(titled: Self.keyboardShortcutsTitle)
            } catch FloError.notFound {
                open = false
            } catch {
                Log.info(.engine, "could not check for the Keyboard Shortcuts window, staying suspended: \(error)")
                return
            }
            guard number == self.shortcutsCheck, !open else { return }
            self.engine.resume(Self.keyboardShortcuts)
        }
    }
}
