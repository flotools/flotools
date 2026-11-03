import FloEngine
import FloProTools
import FloSystem

/// The preset keys, which plug-in and AudioSuite windows share: `]` and `[` step through the presets and speak the new one; Opt+Cmd+P speaks the preset, and on a double press opens the preset menu.
enum Presets {
    /// The three preset commands for one kind of window, with the IDs and names they had in each KM group.
    @MainActor
    static func commands(_ kind: PlugInWindow.Kind) -> [Command] {
        let prefix: String, speakChooseID: String, speakChooseName: String, window: ProToolsWindowKind
        switch kind {
        case .plugIn: (prefix, speakChooseID, speakChooseName, window) = ("plugin", "speakChoosePreset", "Speak/Choose Preset", .plugIn)
        case .audioSuite: (prefix, speakChooseID, speakChooseName, window) = ("audioSuite", "speakChooseAudioSuitePreset", "Speak/Choose Audio Suite Preset", .audioSuite)
        }
        let scope: Scope = .windows([window])
        return [
            step(CommandID("\(prefix).nextPreset"), "Next Preset", "Loads the next preset and speaks its name.", kind, scope, .next, key: "]"),
            step(CommandID("\(prefix).previousPreset"), "Previous Preset", "Loads the previous preset and speaks its name.", kind, scope, .previous, key: "["),
            Command(CommandID("\(prefix).\(speakChooseID)"), speakChooseName, summary: "Single press speaks the preset; double press opens the preset menu.", scope: scope, triggers: [.key("Opt+Cmd+P")], single: { _ in
                let preset = try await ProToolsApp.running().plugInWindow(kind).preset
                try await VoiceOver.say(preset)
            }, double: { _ in
                try await ProToolsApp.running().plugInWindow(kind).openPresetMenu()
            }),
        ]
    }

    @MainActor
    private static func step(_ id: CommandID, _ name: String, _ summary: String, _ kind: PlugInWindow.Kind, _ scope: Scope, _ step: PlugInWindow.PresetStep, key: String) -> Command {
        Command(id, name, summary: summary, scope: scope, triggers: [.key(key)]) { _ in
            let preset = try await ProToolsApp.running().plugInWindow(kind).step(step)
            try await VoiceOver.say(preset)
        }
    }
}
