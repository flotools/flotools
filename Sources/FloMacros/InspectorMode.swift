import FloEngine
import FloProTools
import FloSystem

/// Turning the Flo Tools Inspector group on and off. While it is on, plain keys such as S and Ctrl+Cmd+Right act on the track under the VoiceOver cursor; while it is off, they go to Pro Tools.
enum InspectorMode {
    /// Front window condition of Toggle Inspector and Toggle Temporary Inspector, the same as the Inspector group's. The KM version's `^Mix:|Edit:` also took `/` in any window with "Edit:" in its title, where the Inspector keys do not work; narrowed on purpose (2026-11-03).
    static let mixOrEdit = TitleCondition.matches("^(Mix|Edit):")
    static let toggleTemporaryInspector: MacroID = "floTools.toggleTemporaryInspector"
    static let nextTrackView: MacroID = "floTools.nextTrackViewOnSelectedTracks"
    static let previousTrackView: MacroID = "floTools.previousTrackViewOnSelectedTracks"

    @MainActor
    static var macros: [Macro] { [
        // Only Flo Tools state changes, so the body stays on the main actor.
        Macro("floTools.toggleInspector", "Toggle Inspector", group: .floTools, triggers: [.key("/")]) { @MainActor run in
            guard mixOrEdit.matches(run.context.windowTitle) else {
                run.passThrough()
                return
            }
            let on = !run.engine.isGroupActivated(.inspector)
            setInspector(on, in: run.engine)
            try VoiceOver.say(on ? "Inspector On" : "Inspector Off")
        },
        // A hold, so the Inspector turns off on release even if the key stops being a hotkey meanwhile. The KM version read the key state on press and release instead.
        Macro(toggleTemporaryInspector, "Toggle Temporary INspector", group: .floTools, triggers: [.key("`"), .key("`", .released)], press: { run in
            guard mixOrEdit.matches(run.context.windowTitle) else {
                // The KM version typed a backtick on release too; only the press is passed on here.
                run.passThrough()
                return false
            }
            run.engine.setGroup(.inspector, activated: true)
            return true
        }, release: { run in
            run.engine.setGroup(.inspector, activated: false)
        }),
        trackView(nextTrackView, "Next track view on selected tracks", key: "Ctrl+Cmd+Right", inspectorMacro: "inspector.panRightOnMonoLeftChannel"),
        trackView(previousTrackView, "Previous track view on selected tracks", key: "Ctrl+Cmd+Left", inspectorMacro: "inspector.panLeftOnMonoLeftChannel"),
    ] }

    /// Activates or deactivates the Inspector group. The track view macros share their keys with Inspector pan macros, so they are enabled only while the Inspector is off.
    @MainActor
    static func setInspector(_ on: Bool, in engine: MacroEngine) {
        engine.batch {
            engine.setGroup(.inspector, activated: on)
            engine.setMacro(nextTrackView, enabled: !on)
            engine.setMacro(previousTrackView, enabled: !on)
        }
    }

    /// Pro Tools' own track view shortcut, spoken. Off by default; Toggle Inspector turns these on while the Inspector is off.
    @MainActor
    static func trackView(_ id: MacroID, _ name: String, key: String, inspectorMacro: MacroID) -> Macro {
        Macro(id, name, group: .floTools, enabledByDefault: false, triggers: [.key(key)]) { run in
            if await run.engine.isGroupActive(.inspector) {
                try await run.run(inspectorMacro)
            } else {
                try await ProToolsApp.running().keystroke(KeyCombo(key)!)
                try await VoiceOver.say(name + ".")
            }
        }
    }

    /// Preference effects, like the KM Refresh Preference macro: Toggle Temporary Inspector works only with "temporary inspector" set.
    @MainActor
    static func apply(_ preferences: Preferences, to engine: MacroEngine) {
        engine.setMacro(toggleTemporaryInspector, enabled: preferences.temporaryInspector)
    }

    /// The Inspector state at Flo Tools and Pro Tools launch, from "starts with Flo Tools inspector", like the KM Check for Automatic Update macro. The KM version changed only the group, so the track view keys stayed off until `/` was pressed once; here they follow the Inspector from launch (changed on purpose, 2026-11-03).
    @MainActor
    static func applyStartState(_ preferences: Preferences, to engine: MacroEngine) {
        setInspector(preferences.startsWithInspector, in: engine)
    }
}
