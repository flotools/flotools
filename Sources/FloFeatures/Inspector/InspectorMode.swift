import FloEngine
import FloProTools
import FloSystem

/// Turning the Flo Tools Inspector on and off. While it is on, plain keys such as S and Ctrl+Cmd+Right act on the track under the VoiceOver cursor; while it is off, they go to Pro Tools.
enum InspectorMode {
    static let toggleTemporaryInspector: CommandID = "floTools.toggleTemporaryInspector"

    /// Toggle Inspector and Toggle Temporary Inspector work in the windows the Inspector keys work in. The KM version's `^Mix:|Edit:` also took `/` in any window with "Edit:" in its title, and its macros passed the key on in other windows; narrowed on purpose (2026-11-03), so the key is not taken there at all.
    @MainActor
    static var commands: [Command] { [
        // Only Flo Tools state changes, so the body stays on the main actor.
        Command("floTools.toggleInspector", "Toggle Inspector", summary: "Turns the Inspector on or off and says which.", scope: .mixOrEdit, triggers: [.key("/")]) { @MainActor run in
            let on = !run.engine.mode.inspector
            run.engine.setInspector(on)
            try await VoiceOver.say(on ? "Inspector On" : "Inspector Off")
        },
        // A hold, so the Inspector turns off on release even if the key stops being a hotkey meanwhile. The KM version read the key state on press and release instead. Release always turns it off, also when `/` had turned it on.
        Command(toggleTemporaryInspector, "Toggle Temporary Inspector", summary: "Turns the Inspector on while the key is held, and off when it is released. Works only with the \"temporary inspector\" preference on.", scope: .mixOrEdit, triggers: [.key("`"), .key("`", .released)], press: { run in
            run.engine.setInspector(true)
            return true
        }, release: { run in
            run.engine.setInspector(false)
        }),
    ] }

    /// Preference effects, like the KM Refresh Preference macro: Toggle Temporary Inspector works only with "temporary inspector" set.
    @MainActor
    static func apply(_ preferences: Preferences, to engine: Engine) {
        engine.setCommand(toggleTemporaryInspector, enabled: preferences.temporaryInspector)
    }

    /// The Inspector state at Flo Tools and Pro Tools launch, from "starts with Flo Tools inspector", like the KM Check for Automatic Update macro.
    @MainActor
    static func applyStartState(_ preferences: Preferences, to engine: Engine) {
        engine.setInspector(preferences.startsWithInspector)
    }
}
