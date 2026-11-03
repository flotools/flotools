import FloEngine
import FloProTools
import FloSystem

/// Pro Tools shortcuts that Flo Tools passes on to Pro Tools and then announces, because Pro Tools changes nothing VoiceOver reads: selecting playlists, switching track views and heights, and choosing the keyboard focus.
enum KeyAnnouncements {
    @MainActor
    static var macros: [Macro] { [
        speakSelectedTracks("floTools.speakAndSelectNextPlaylist", "Speak And Select Next Playlist", key: "Shift+Down"),
        speakSelectedTracks("floTools.speakAndSelectPreviousPlaylist", "Speak And Select Previous Playlist", key: "Shift+Up"),
        speakSelectedTracks("floTools.speakAndMoveAhead5Playlists", "Speak And Move Ahead 5 Playlists", key: "Shift+Page Down"),
        speakSelectedTracks("floTools.speakAndMoveBack5Playlists", "Speak And Move Back 5 Playlists", key: "Shift+Page Up"),
        speakSelectedTracks("floTools.speakAndNavigateToFirstPlaylist", "Speak And Navigate to First Playlist", key: "Shift+Home"),
        speakSelectedTracks("floTools.speakAndNavigateToLastPlaylist", "Speak And Navigate to Last Playlist", key: "Shift+End"),
        announce("floTools.nextTrackViewOnAllTracks", "Next track view on All tracks", keys: ["Ctrl+Opt+Cmd+Right"], "Next track view on All tracks.", when: .always),
        announce("floTools.previousTrackViewOnAllTracks", "Previous track view on All tracks", keys: ["Ctrl+Opt+Cmd+Left"], "Previous track view on All tracks.", when: .always),
        // Pro Tools 26.10 toggles the view of all tracks with Ctrl+Opt+- and ignores the Opt+- the KM version sent (checked live 2026-11-03); the hotkey stays Opt+-.
        announce("floTools.trackViewToggledOnAllTracks", "Track view toggled on all tracks", keys: ["Opt+-"], sends: "Ctrl+Opt+-", "Track view toggled on all tracks.", when: .outsideListedDialogsAndText),
        // Both keys send Down, as in the KM version.
        announce("floTools.adjustAllTrackHeightsToFitInEditWindow", "Adjust all track heights to fit in Edit window", keys: ["Ctrl+Opt+Cmd+Up", "Ctrl+Opt+Cmd+Down"], sends: "Ctrl+Opt+Cmd+Down", "Adjust all track heights to fit in Edit window..", when: .always),
        announce("floTools.selectEditKeyboardFocus", "Select Edit Keyboard Focus", keys: ["Opt+Cmd+1"], "Edit Keyboard Focus", when: .inEditWindow),
        announce("floTools.selectClipsKeyboardFocus", "Select Clips Keyboard Focus", keys: ["Opt+Cmd+2"], "Clips Keyboard Focus", when: .inEditWindow),
        announce("floTools.selectGroupsKeyboardFocus", "Select Groups Keyboard Focus", keys: ["Opt+Cmd+3"], "Groups Keyboard Focus", when: .inEditWindow),
    ] }

    /// Sends the key, or `sends` instead, to Pro Tools and speaks `text` if the guard allows it.
    @MainActor
    private static func announce(_ id: MacroID, _ name: String, keys: [String], sends: String? = nil, _ text: String, when guarding: AnnouncementGuard) -> Macro {
        let replacement = sends.map { KeyCombo($0)! }
        return Macro(id, name, scope: .anyProToolsWindow, triggers: keys.map { .key($0) }) { run in
            if let replacement {
                try await ProToolsApp.running().keystroke(replacement)
            } else {
                await run.passThrough()
            }
            if try await speaks(after: guarding) { try await VoiceOver.say(text) }
        }
    }

    /// Sends the key, which in Pro Tools selects another playlist on the selected tracks, and speaks the selected tracks from the Mix window's Track List, as the JXA did. The selection read before the key is only for waiting until Pro Tools shows the new one, so its failure does not keep the key from Pro Tools.
    @MainActor
    private static func speakSelectedTracks(_ id: MacroID, _ name: String, key: String) -> Macro {
        Macro(id, name, scope: .anyProToolsWindow, triggers: [.key(key)]) { run in
            let before = try? await selectedTracksText(try ProToolsApp.running())
            await run.passThrough()
            guard try await speaks(after: .outsideListedDialogsAndText) else { return }
            let app = try ProToolsApp.running()
            let after = try await ProToolsUpdate.reading(changedFrom: before ?? "", within: .milliseconds(500)) { try selectedTracksText(app) }
            try await VoiceOver.say(after)
        }
    }

    /// Whether to speak after a shortcut went to Pro Tools, read now, after the key, as the KM versions did.
    static func speaks(after guarding: AnnouncementGuard) async throws -> Bool {
        guard guarding != .always else { return true }
        let cursorText = guarding.readsKeyboardCursor ? try await VoiceOver.keyboardCursorText() : nil
        let window = try await ProToolsApp.running().frontWindowFacts()
        return guarding.allows(window, keyboardCursorText: cursorText)
    }

    @AccessibilityActor
    private static func selectedTracksText(_ app: ProToolsApp) throws -> String {
        selectedTracksText(names: try app.mixWindow().trackList().rows().filter(\.isSelected).map(\.name))
    }

    /// "Kick - Audio. Snare - Audio. ", as the JXA spoke the selected tracks.
    static func selectedTracksText(names: [String]) -> String {
        names.isEmpty ? "No tracks are selected." : TrackStatus.list(names)
    }
}
