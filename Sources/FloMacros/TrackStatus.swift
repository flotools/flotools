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

    /// Same text as the JXA version: "2 Soloed: Kick - Audio. Snare - Audio. "
    static func soloedMessage(names: [String]) -> String {
        guard !names.isEmpty else { return "No tracks are soloed." }
        let list = names.map { $0 + ". " }.joined().replacingOccurrences(of: " Track . ", with: ". ")
        return "\(names.count) Soloed: \(list)"
    }

    static func speakSoloed() async throws {
        let mix = try await ProToolsApp.running().mixWindow()
        let names = try await mix.soloedTracks().map(\.name)
        try await VoiceOver.say(soloedMessage(names: names))
    }

    /// Unsolos every soloed track, folders last, as the JXA did. Active mix groups are suspended meanwhile, so one click does not toggle a whole group, and resumed however the loop ends: done, failed or cancelled. Each track is checked again before its click, because unsoloing a folder or a grouped track can unsolo others. Success is spoken only when every track was handled; a failure part way says how far it got.
    static func unsoloAll() async throws {
        let proTools = try ProToolsApp.running()
        let mix = try await proTools.mixWindow()
        let soloed = try await mix.soloedTracks()
        let ordered = soloed.filter { !$0.isFolder } + soloed.filter(\.isFolder)
        let suspendGroups = ordered.isEmpty ? false : try await mix.hasActiveGroups()
        if suspendGroups { try await proTools.setGroups(suspended: true, in: mix) }
        // `defer` cannot await, so the loop's error is kept and thrown after the groups are resumed.
        var handled = 0
        var loopError: (any Error)?
        do {
            var lastSound = ContinuousClock.now
            for track in ordered {
                // A stop request ends the loop between clicks.
                try Task.checkCancellation()
                try await unsoloIfSoloed(track)
                handled += 1
                if ContinuousClock.now - lastSound > .seconds(1) {
                    await Sound.progress.play()
                    lastSound = .now
                }
            }
        } catch {
            loopError = error
        }
        if suspendGroups {
            do {
                try await proTools.setGroups(suspended: false, in: mix)
            } catch {
                // The loop's error is what the user hears; this one goes to the log.
                if loopError == nil { loopError = error } else { Log.error(.engine, "after a failed Unsolo All: \(error)") }
            }
        }
        if let loopError {
            if let cause = loopError as? FloError, handled > 0 {
                throw FloError.incomplete(done: "Unsoloed \(handled) of \(ordered.count) tracks", cause: cause)
            }
            throw loopError
        }
        // A stop request during the last click must not be announced as success.
        try Task.checkCancellation()
        try await VoiceOver.say("unsoloed all tracks.")
    }

    @AccessibilityActor
    private static func unsoloIfSoloed(_ track: TrackStrip) throws {
        guard try track.isSoloed() else { return }
        try track.button(.solo).press()
    }
}
