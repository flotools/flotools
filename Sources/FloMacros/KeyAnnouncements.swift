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
        announce("floTools.trackViewToggledOnAllTracks", "Track view toggled on all tracks", keys: ["Opt+-"], "Track view toggled on all tracks.", when: .keyReachesWindow),
        // Both keys send Down, as in the KM version.
        announce("floTools.adjustAllTrackHeightsToFitInEditWindow", "Adjust all track heights to fit in Edit window", keys: ["Ctrl+Opt+Cmd+Up", "Ctrl+Opt+Cmd+Down"], sends: "Ctrl+Opt+Cmd+Down", "Adjust all track heights to fit in Edit window..", when: .always),
        announce("floTools.selectEditKeyboardFocus", "Select Edit Keyboard Focus", keys: ["Opt+Cmd+1"], "Edit Keyboard Focus", when: .editWindowInFront),
        announce("floTools.selectClipsKeyboardFocus", "Select Clips Keyboard Focus", keys: ["Opt+Cmd+2"], "Clips Keyboard Focus", when: .editWindowInFront),
        announce("floTools.selectGroupsKeyboardFocus", "Select Groups Keyboard Focus", keys: ["Opt+Cmd+3"], "Groups Keyboard Focus", when: .editWindowInFront),
    ] }

    /// When the announcement is spoken after the key went to Pro Tools.
    enum Condition: Sendable {
        case always
        /// Not while a text field has the keyboard focus or a dialog is in front, where the key is typed or does something else. The KM version checked the VoiceOver keyboard cursor and a list of dialog titles.
        case keyReachesWindow
        /// The keyboard focus keys act only in the Edit window.
        case editWindowInFront
    }

    /// Sends the key, or `sends` instead, to Pro Tools and speaks `text` if `condition` holds.
    @MainActor
    private static func announce(_ id: MacroID, _ name: String, keys: [String], sends: String? = nil, _ text: String, when condition: Condition) -> Macro {
        let replacement = sends.map { KeyCombo($0)! }
        return Macro(id, name, group: .floTools, triggers: keys.map { .key($0) }) { run in
            let app = try ProToolsApp.running()
            let speaks = switch condition {
            case .always: true
            case .keyReachesWindow: try await !app.keysGoToTextOrDialog()
            case .editWindowInFront: run.context.windowTitle?.hasPrefix("Edit:") == true
            }
            if let replacement {
                await app.keystroke(replacement)
            } else {
                await run.passThrough()
            }
            if speaks { try await VoiceOver.say(text) }
        }
    }

    /// Sends the key, which in Pro Tools moves or extends the track selection, and speaks the selected tracks from the Mix window's Track List, unless the key was typed into a text field or went to a dialog. Pro Tools may take a moment to show the new selection.
    @MainActor
    private static func speakSelectedTracks(_ id: MacroID, _ name: String, key: String) -> Macro {
        Macro(id, name, group: .floTools, triggers: [.key(key)]) { run in
            let app = try ProToolsApp.running()
            let speaks = try await !app.keysGoToTextOrDialog()
            let before = speaks ? try await selectedTracksText(app) : ""
            await run.passThrough()
            guard speaks else { return }
            let after = try await ProToolsUpdate.reading(changedFrom: before, within: .milliseconds(500)) { try selectedTracksText(app) }
            try await VoiceOver.say(after)
        }
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
