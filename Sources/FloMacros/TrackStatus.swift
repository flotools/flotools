import Foundation
import FloEngine
import FloProTools
import FloSystem

/// Macros that report or reset track states in the Mix window.
enum TrackStatus {
    @MainActor
    static var macros: [Macro] { [
        Macro("floTools.speakSoloedTracksUnsoloAllTracks", "Speak Soloed Tracks, Unsolo All Tracks", group: .floTools, triggers: [.key("Opt+Shift+S")], single: { _ in
            try await speakSoloed()
        }, double: { _ in
            try await unsoloAll()
        }),
    ] }

    // MARK: Solo

    /// A track counts as soloed when its Solo button value is not empty and not "safe" or "inactive". The master track is skipped.
    static func isSoloed(trackName: String, soloValue: String) -> Bool {
        !trackName.localizedCaseInsensitiveContains(" - Master Track")
            && !soloValue.isEmpty
            && !soloValue.localizedCaseInsensitiveContains("safe")
            && !soloValue.localizedCaseInsensitiveContains("inactive")
    }

    /// A strip without a name or Solo button (the Group List and the like) is skipped. A Solo button without a value counts as not soloed, as in the JXA; a failed read throws, so a busy Pro Tools is never reported as "No tracks are soloed".
    @AccessibilityActor
    static func soloedTracks(in mix: AXElement) throws -> [(name: String, solo: AXElement)] {
        try mix.groups.compactMap { track in
            guard let name = try track.name, let solo = try track.button("Solo") else { return nil }
            return isSoloed(trackName: name, soloValue: try solo.value ?? "") ? (name, solo) : nil
        }
    }

    /// Same text as the JXA version: "2 Soloed: Kick - Audio. Snare - Audio. "
    static func soloedMessage(names: [String]) -> String {
        guard !names.isEmpty else { return "No tracks are soloed." }
        let list = names.map { $0 + ". " }.joined().replacingOccurrences(of: " Track . ", with: ". ")
        return "\(names.count) Soloed: \(list)"
    }

    static func speakSoloed() async throws {
        let names = try await soloedTrackNames()
        try await VoiceOver.say(soloedMessage(names: names))
    }

    @AccessibilityActor
    static func soloedTrackNames() throws -> [String] {
        try soloedTracks(in: ProTools.mixWindow()).map(\.name)
    }

    /// Clicks every soloed track's Solo button, folders last. Active mix groups are suspended meanwhile so one click doesn't toggle a whole group, and resumed however the loop ends: done, failed or cancelled. Success is spoken only when every click worked.
    static func unsoloAll() async throws {
        let mix = try await ProTools.mixWindow()
        let tracks = try await soloedTracks(in: mix)
        let suspendGroups = tracks.isEmpty ? false : try await hasActiveGroups(in: mix)
        let suspendKey = KeyCombo("Cmd+Shift+G")!
        let ordered = tracks.filter { !$0.name.contains("Folder Track") } + tracks.filter { $0.name.contains("Folder Track") }
        if suspendGroups { try await ProTools.keystroke(suspendKey) }
        // The groups are resumed however the loop ends, before anything is spoken. `defer` cannot await the keystroke, so the loop's error is kept and thrown afterwards; it wins over a failure to resume.
        var loopError: (any Error)?
        do {
            var lastSound = ContinuousClock.now
            for track in ordered {
                // A stop request ends the loop between clicks.
                try Task.checkCancellation()
                try await track.solo.press()
                if ContinuousClock.now - lastSound > .seconds(1) {
                    await Sound.progress.play()
                    lastSound = .now
                }
            }
        } catch {
            loopError = error
        }
        if suspendGroups {
            do { try await ProTools.keystroke(suspendKey) } catch where loopError != nil {
                Log.error(.engine, "could not resume mix groups after a failed Unsolo All: \(error)")
            }
        }
        if let loopError { throw loopError }
        // A stop request during the last click must not be announced as success.
        try Task.checkCancellation()
        try await VoiceOver.say("unsoloed all tracks.")
    }

    /// Whether any row in the Group List has its first button named "Active ...". No Group List means no active groups.
    @AccessibilityActor
    static func hasActiveGroups(in mix: AXElement) throws -> Bool {
        guard let rows = try mix.table("Group List")?.rows else { return false }
        return try rows.contains { row in
            let cells = try row.children
            guard cells.count > 1, let name = try cells[1].buttons.first?.name else { return false }
            return name.lowercased().hasPrefix("active ")
        }
    }
}
