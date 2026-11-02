import Foundation
import FloToolsCore

/// Macros that report or reset track states in the Mix window.
enum TrackStatus {
    @MainActor
    static let macros = [
        Macro("floTools.speakSoloedTracksUnsoloAllTracks", "Speak Soloed Tracks, Unsolo All Tracks", group: .floTools, triggers: [.key("Opt+Shift+S")]) { _ in
            DoublePress.shared.press("gs", single: speakSoloed, double: {
                Sound.play("Tink")
                unsoloAll()
            })
        },
    ]

    // MARK: Solo

    /// A track counts as soloed when its Solo button value is not empty and not "safe" or "inactive". The master track is skipped.
    static func isSoloed(trackName: String, soloValue: String) -> Bool {
        !trackName.localizedCaseInsensitiveContains(" - Master Track")
            && !soloValue.isEmpty
            && !soloValue.localizedCaseInsensitiveContains("safe")
            && !soloValue.localizedCaseInsensitiveContains("inactive")
    }

    @MainActor
    static func soloedTracks(in mix: AXElement) -> [(name: String, solo: AXElement)] {
        mix.groups.compactMap { track in
            guard let name = track.name, let solo = track.button("Solo") else { return nil }
            return isSoloed(trackName: name, soloValue: solo.value ?? "") ? (name, solo) : nil
        }
    }

    /// Same text as the JXA version: "2 Soloed: Kick - Audio. Snare - Audio. "
    static func soloedMessage(names: [String]) -> String {
        guard !names.isEmpty else { return "No tracks are soloed." }
        let list = names.map { $0 + ". " }.joined().replacingOccurrences(of: " Track . ", with: ". ")
        return "\(names.count) Soloed: \(list)"
    }

    @MainActor
    static func speakSoloed() {
        guard let mix = ProTools.mixWindow else { return }
        VoiceOver.say(soloedMessage(names: soloedTracks(in: mix).map(\.name)))
    }

    /// Clicks every soloed track's Solo button, folders last. Active mix groups are suspended meanwhile so one click doesn't toggle a whole group.
    @MainActor
    static func unsoloAll() {
        guard let mix = ProTools.mixWindow else { return }
        let tracks = soloedTracks(in: mix)
        let suspendGroups = !tracks.isEmpty && hasActiveGroups(in: mix)
        let suspendKey = KeyCombo(keyCode: 5, modifiers: KeyCombo.command | KeyCombo.shift) // Cmd+Shift+G
        if suspendGroups { ProTools.keystroke(suspendKey) }

        var lastSound = ContinuousClock.now
        let ordered = tracks.filter { !$0.name.contains("Folder Track") } + tracks.filter { $0.name.contains("Folder Track") }
        for track in ordered {
            track.solo.press()
            if ContinuousClock.now - lastSound > .seconds(1) {
                Sound.play("Pop")
                lastSound = .now
            }
        }

        if suspendGroups { ProTools.keystroke(suspendKey) }
        VoiceOver.say("unsoloed all tracks.")
    }

    /// Whether any row in the Group List has its first button named "Active ...".
    @MainActor
    static func hasActiveGroups(in mix: AXElement) -> Bool {
        guard let rows = mix.table("Group List")?.rows else { return false }
        return rows.contains { row in
            let cells = row.children
            guard cells.count > 1, let name = cells[1].buttons.first?.name else { return false }
            return name.lowercased().hasPrefix("active ")
        }
    }
}
