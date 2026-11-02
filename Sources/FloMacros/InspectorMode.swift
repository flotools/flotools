import CoreGraphics
import FloToolsCore

/// Turning the Flo Tools Inspector group on and off. While it is on, plain keys such as S and Ctrl+Cmd+Right act on the track under the VoiceOver cursor; while it is off, they go to Pro Tools.
enum InspectorMode {
    /// Front window condition of Toggle Inspector and Toggle Temporary Inspector. Slightly wider than the Inspector group's `^(Mix|Edit):`, as in the KM version.
    static let mixOrEdit = TitleCondition.matches("^Mix:|Edit:")
    static let toggleTemporaryInspector: MacroID = "floTools.toggleTemporaryInspector"
    static let nextTrackView: MacroID = "floTools.nextTrackViewOnSelectedTracks"
    static let previousTrackView: MacroID = "floTools.previousTrackViewOnSelectedTracks"
    static let backtick: UInt16 = 50

    @MainActor
    static let macros = [
        Macro("floTools.toggleInspector", "Toggle Inspector", group: .floTools, triggers: [.key("/")]) { engine in
            guard mixOrEdit.matches(engine.context.windowTitle) else {
                HotKeyCenter.shared.passThrough(KeyCombo("/")!)
                return
            }
            let on = !engine.isGroupActivated(.inspector)
            setInspector(on, in: engine)
            VoiceOver.say(on ? "Inspector On" : "Inspector Off")
        },
        // Fires on press and release; the KM version read the key state rather than the trigger.
        Macro(toggleTemporaryInspector, "Toggle Temporary INspector", group: .floTools, triggers: [.key("`"), .key("`", .released)]) { engine in
            let down = CGEventSource.keyState(.combinedSessionState, key: backtick)
            guard mixOrEdit.matches(engine.context.windowTitle) else {
                // The KM version typed a backtick on release too; only the press is passed on here.
                if down { HotKeyCenter.shared.passThrough(KeyCombo("`")!) }
                return
            }
            engine.setGroup(.inspector, activated: down)
        },
        trackView(nextTrackView, "Next track view on selected tracks", key: "Ctrl+Cmd+Right", inspectorMacro: "inspector.panRightOnMonoLeftChannel"),
        trackView(previousTrackView, "Previous track view on selected tracks", key: "Ctrl+Cmd+Left", inspectorMacro: "inspector.panLeftOnMonoLeftChannel"),
    ]

    /// Activates or deactivates the Inspector group. The track view macros share their keys with Inspector pan macros, so they are enabled only while the Inspector is off.
    @MainActor
    static func setInspector(_ on: Bool, in engine: MacroEngine) {
        engine.setGroup(.inspector, activated: on)
        engine.setMacro(nextTrackView, enabled: !on)
        engine.setMacro(previousTrackView, enabled: !on)
    }

    /// Pro Tools' own track view shortcut, spoken. Off by default; Toggle Inspector turns these on while the Inspector is off.
    @MainActor
    static func trackView(_ id: MacroID, _ name: String, key: String, inspectorMacro: MacroID) -> Macro {
        Macro(id, name, group: .floTools, enabledByDefault: false, triggers: [.key(key)]) { engine in
            if engine.isGroupActivated(.inspector) {
                engine.run(inspectorMacro)
            } else {
                ProTools.keystroke(KeyCombo(key)!)
                VoiceOver.say(name + ".")
            }
        }
    }

    /// Preference effects, like the KM Refresh Preference macro: Toggle Temporary Inspector works only with "temporary inspector" set.
    @MainActor
    static func apply(_ preferences: Preferences, to engine: MacroEngine) {
        engine.setMacro(toggleTemporaryInspector, enabled: preferences.temporaryInspector)
    }

    /// The Inspector state at Flo Tools and Pro Tools launch, from "starts with Flo Tools inspector", like the KM Check for Automatic Update macro. As there, only the group changes; the track view macros keep their state.
    @MainActor
    static func applyStartState(_ preferences: Preferences, to engine: MacroEngine) {
        engine.setGroup(.inspector, activated: preferences.startsWithInspector)
    }
}
