import FloEngine
import FloProTools
import FloSystem

/// AudioSuite window keys: the buttons and presets of the AudioSuite window.
enum AudioSuite {
    @MainActor
    static var macros: [Macro] {
        [
            button("analyze", "Analyze", key: "Ctrl+Opt+Shift+Cmd+N", spoken: "Analyze"),
            button("bypass", "Bypass", key: "Ctrl+Opt+Shift+Cmd+B"),
            button("previewProcessing", "Preview Processing", key: "Ctrl+Opt+Shift+Cmd+P"),
            button("render", "Render", key: "Ctrl+Opt+Shift+Cmd+R", spoken: "Render"),
            PlugIns.stepPreset(MacroID("audioSuite.nextPreset"), "Next Preset", .audioSuite, .next, key: "]"),
            PlugIns.stepPreset(MacroID("audioSuite.previousPreset"), "Previous Preset", .audioSuite, .previous, key: "["),
            PlugIns.speakChoosePreset(MacroID("audioSuite.speakChooseAudioSuitePreset"), "Speak/Choose Audio Suite Preset", .audioSuite),
        ]
    }

    /// Presses the AudioSuite window's button `name` and speaks `spoken` if given, as the JXA did. A missing button is reported through `SpokenError` ("Could not find the Render button.") rather than the JXA's "Can't find render button!".
    @MainActor
    static func button(_ id: String, _ name: String, key: String, spoken: String? = nil) -> Macro {
        Macro(MacroID("audioSuite.\(id)"), name, scope: .windows([.audioSuite]), triggers: [.key(key)]) { _ in
            try await ProToolsApp.running().plugInWindow(.audioSuite).press(name)
            if let spoken { try await VoiceOver.say(spoken) }
        }
    }
}
