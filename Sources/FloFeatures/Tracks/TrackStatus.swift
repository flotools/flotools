import Foundation
import FloEngine
import FloProTools
import FloSystem

/// Flo Tools commands that speak which tracks have a state, and on a double press reset it on all of them: solo, mute, record arm, input monitoring, the safe states, selection, shown and hidden tracks, and tracks that reached 0 dB.
enum TrackStatus {
    @MainActor
    static var commands: [Command] { [
        flagCommand("floTools.speakSoloedTracksUnsoloAllTracks", "Speak Soloed Tracks, Unsolo All Tracks", key: "Opt+Shift+S", "Single press speaks the soloed tracks; double press unsolos them all.", .soloed, Wording(none: NoTracks.soloed, heading: "Soloed:"),
                  reset: Reset(suspendsGroups: true, verb: "unsolo", partly: "Unsoloed", done: "unsoloed all tracks.")),
        flagCommand("floTools.speakMutedTracksUnmuteAllTracks", "Speak Muted Tracks, Unmute All Tracks", key: "Opt+Shift+M", "Single press speaks the muted tracks; double press unmutes them all.", .muted, Wording(none: NoTracks.muted, heading: "Muted:"),
                  reset: Reset(suspendsGroups: true, verb: "unmute", partly: "Unmuted", done: "unmuted all tracks.")),
        flagCommand("floTools.speakInputMonitorEnabledTracksDisableInputMonitorOnAllTracks", "Speak Input Monitor-Enabled Tracks, Disable Input Monitor On All Tracks", key: "Opt+Shift+K", "Single press speaks the tracks with input monitoring on; double press turns it off on all of them.", .inputMonitored, Wording(none: "No track has input monitor on", heading: "Input on:"),
                  reset: Reset(suspendsGroups: false, verb: "turn off input monitor on", partly: "Turned off input monitor on", done: "Turned Off Input Monitor for all tracks")),
        recordArmed,
        flagCommand("floTools.speakRecordSafeTracks", "Speak Record Safe Tracks", key: "Opt+Shift+Cmd+R", "Speaks the tracks that are record safe.", .recordSafe, Wording(none: "No tracks are disarmed safe.", heading: "Disarmed safe:")),
        flagCommand("floTools.speakSoloSafeTracks", "Speak Solo Safe Tracks", key: "Opt+Shift+Cmd+S", "Speaks the tracks that are solo safe.", .soloSafe, Wording(none: "No tracks are solo safe.", heading: "Solo safe:")),
        Command("floTools.speakTracksWith0DbLevel", "Speak Tracks With 0DB Level", summary: "Speaks the tracks whose volume fader is at 0 dB.", scope: .anyProToolsWindow, triggers: [.key("Opt+Shift+0")]) { _ in
            try await speakTracksAt0dB()
        },
        Command("floTools.speakSelectedTracksDeselectAllTracks", "Speak Selected Tracks, Deselect All Tracks", summary: "Single press speaks the selected tracks; double press deselects them all.", scope: .anyProToolsWindow, triggers: [.key("Opt+Shift+L")], single: { _ in
            try await speak(.trackList(.selected, on: true), Wording(none: NoTracks.selected, heading: "selected."))
        }, double: { _ in
            try await deselectAll()
        }),
        Command("floTools.speakHiddenTracksShowTrackListPopUpMenu", "Speak Hidden Tracks, Show Track List Pop-up Menu", summary: "Single press speaks the hidden tracks; double press opens the Track List menu.", scope: .anyProToolsWindow, triggers: [.key("Opt+Shift+H")], single: { _ in
            try await speak(.trackList(.shown, on: false), Wording(none: NoTracks.hidden, heading: "Hidden:"))
        }, double: { _ in
            try await ProToolsApp.running().mixWindow().openTrackListMenu()
        }),
        Command("floTools.speakShownTracksShowTrackListPopUpMenu", "Speak Shown Tracks, Show Track List Pop-up Menu", summary: "Single press speaks the shown tracks; double press opens the Track List menu.", scope: .anyProToolsWindow, triggers: [.key("Opt+Shift+W")], single: { _ in
            try await speak(.trackList(.shown, on: true), Wording(none: NoTracks.shown, heading: "Shown:"))
        }, double: { _ in
            try await ProToolsApp.running().mixWindow().openTrackListMenu()
        }),
    ] }

    // MARK: Speaking a list of tracks

    /// What a report says. `heading` follows the number of tracks, for example "2 Soloed: Kick - Audio. Snare - Audio. ".
    struct Wording: Sendable {
        let none: String
        let heading: String
    }

    /// The JXA text: "<count> <heading> " and each name with ". ", where a name's trailing "Track " is dropped, so "Kick - Audio Track " is spoken "Kick - Audio". The JXA versions differed in whether that cleanup matched; here it is the same for all.
    static func message(names: [String], _ wording: Wording) -> String {
        guard !names.isEmpty else { return wording.none }
        return "\(names.count) \(wording.heading) " + list(names)
    }

    static func list(_ names: [String]) -> String {
        names.map { $0 + ". " }.joined().replacingOccurrences(of: " Track . ", with: ". ")
    }

    // MARK: Strip flags

    /// What a double press does: set the flag off on every track that has it.
    struct Reset: Sendable {
        /// Solo and mute suspend the mix groups meanwhile, as the JXA did, so one click does not change a whole group.
        let suspendsGroups: Bool
        /// What failed on a track whose flag stayed on, for example "unsolo" in "Could not unsolo Kick."
        let verb: String
        /// Starts the report of a run that failed part way, for example "Unsoloed 2 of 5 tracks".
        let partly: String
        /// Spoken when every track was handled.
        let done: String
    }

    @MainActor
    private static func flagCommand(_ id: CommandID, _ name: String, key: String, _ summary: String, _ flag: TrackFlag, _ wording: Wording, reset: Reset? = nil) -> Command {
        let speak: CommandBody = { _ in try await TrackStatus.speak(.strips(flag, on: true), wording) }
        guard let reset else {
            return Command(id, name, summary: summary, scope: .anyProToolsWindow, triggers: [.key(key)], body: speak)
        }
        return Command(id, name, summary: summary, scope: .anyProToolsWindow, triggers: [.key(key)], single: speak, double: { _ in
            try await resetAll(flag, reset)
            try await VoiceOver.say(reset.done)
        })
    }

    static func speak(_ tracks: TrackQuery, _ wording: Wording) async throws {
        let names = try await ProToolsApp.running().mixWindow().names(tracks)
        try await VoiceOver.say(message(names: names, wording))
    }

    /// Record arm has two extra cases: armed tracks can be hidden, which only the Edit window's record status shows, as the JXA checked. The JXA disarmed in a loop until that status cleared, which never ended while a hidden track was armed; this disarms the shown tracks once and says when hidden ones stay armed.
    @MainActor
    private static var recordArmed: Command {
        Command("floTools.speakRecordEnabledTracksDisarmAllRecordEnabledTracks", "Speak Record-Enabled Tracks, Disarm All Record-Enabled Tracks", summary: "Single press speaks the record-armed tracks, and says when hidden tracks are armed; double press disarms them all.", scope: .anyProToolsWindow, triggers: [.key("Opt+Shift+R")], single: { _ in
            let proTools = try ProToolsApp.running()
            let names = try await proTools.mixWindow().tracks(.recordArmed, on: true).map(\.name)
            try await VoiceOver.say(names.isEmpty ? noArmedTracksText(proTools) : "\(names.count) Armed: " + list(names))
        }, double: { _ in
            let reset = Reset(suspendsGroups: false, verb: "disarm", partly: "Disarmed", done: "Disarmed all tracks.")
            try await resetAll(.recordArmed, reset)
            let hiddenStillArmed = try await ProToolsApp.running().hasArmedTracks()
            try await VoiceOver.say(hiddenStillArmed ? "Disarmed all shown tracks. Some hidden tracks are still armed." : reset.done)
        })
    }

    /// For an empty list of armed tracks: whether hidden tracks are armed.
    static func noArmedTracksText(_ proTools: ProToolsApp) async throws -> String {
        try await proTools.hasArmedTracks() ? "Some tracks are armed." : NoTracks.armed
    }

    /// Turns `flag` off on every track that has it, folders last, as the JXA did for solo. Each track is checked again before its click, because a click on a folder or a grouped track can change others, and the click waits for the button to change before the next one. A track whose flag stays on stops the loop with `FloError.couldNot`. Mix groups are suspended meanwhile if `reset` says so, and resumed however the loop ends: done, failed or cancelled. A failure part way says how far it got.
    static func resetAll(_ flag: TrackFlag, _ reset: Reset) async throws {
        let proTools = try ProToolsApp.running()
        let mix = try await proTools.mixWindow()
        let tracks = try await mix.tracks(flag, on: true)
        let ordered = tracks.filter { $0.kind != .folder } + tracks.filter { $0.kind == .folder }
        let suspendGroups = reset.suspendsGroups && !ordered.isEmpty ? try await mix.hasActiveGroups() : false
        // `defer` cannot await, so the loop's error is kept and thrown after the groups are resumed.
        var handled = 0
        var loopError: (any Error)?
        var groupsSuspended = false
        do {
            if suspendGroups {
                do {
                    try await proTools.setGroups(suspended: true, in: mix)
                } catch {
                    // The command was sent but not confirmed. Resume only groups that read as suspended: Cmd+Shift+G switches, so resuming blindly could suspend them.
                    groupsSuspended = (try? await mix.hasActiveGroups()) == false
                    throw error
                }
                groupsSuspended = true
            }
            var progress = ProgressTicker(every: .seconds(1))
            for track in ordered {
                // A stop request ends the loop between clicks.
                try Task.checkCancellation()
                // The click waits only so long for the button, so a track still soloed must not be counted, or success would be spoken.
                guard try await track.set(flag, to: false) else { throw FloError.couldNot("\(reset.verb) \(track.name)") }
                handled += 1
                await progress.tick()
            }
        } catch {
            loopError = error
        }
        if groupsSuspended {
            do {
                try await proTools.setGroups(suspended: false, in: mix)
            } catch {
                // The loop's error is what the user hears; this one goes to the log.
                if loopError == nil { loopError = error } else { Log.error(.engine, "after a failed reset of \(flag): \(error)") }
            }
        }
        if let loopError {
            if let cause = loopError as? FloError, handled > 0 {
                throw FloError.incomplete(done: "\(reset.partly) \(handled) of \(ordered.count) tracks", cause: cause)
            }
            throw loopError
        }
        // A stop request during the last click must not be announced as success.
        try Task.checkCancellation()
    }

    // MARK: 0 dB

    /// Tracks whose peak hold reached 0 dB or more. MIDI tracks have no audio meter and are left out, as in the JXA.
    static func speakTracksAt0dB() async throws {
        let names = try await tracksAt0dB()
        // The JXA said "reched"; corrected.
        try await VoiceOver.say(names.isEmpty ? "No track reached 0db level." : "0db on: " + list(names))
    }

    @AccessibilityActor
    private static func tracksAt0dB() throws -> [String] {
        try ProToolsApp.running().mixWindow().trackStrips().filter { strip in
            guard strip.kind != .midi else { return false }
            return try strip.peakDecibels().map { $0 >= 0 } ?? false
        }.map(\.name)
    }

    // MARK: Track List

    /// Deselects each selected track in the Track List, after expanding the list if it is collapsed, as the JXA did. Pro Tools may take a moment to show the change, so the check waits briefly; a track still selected after it is a failure.
    @AccessibilityActor
    static func deselectAll() async throws {
        let mix = try ProToolsApp.running().mixWindow()
        try mix.expandTrackList()
        let list = try mix.trackList()
        for row in try list.rows() where row.isSelected {
            try Task.checkCancellation()
            try row.toggle(.selected)
        }
        let stillSelected = try await ProToolsUpdate.reading(changedFrom: true) { try list.rows().contains(where: \.isSelected) }
        // The JXA said "Please expand track list table." here, but the list was just expanded, so the cause is unknown.
        guard !stillSelected else { throw FloError.couldNot("deselect all tracks") }
        try await VoiceOver.say("Deselected All Tracks.")
    }
}
