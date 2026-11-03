import Foundation
import FloEngine
import FloProTools
import FloSystem

/// Flo Tools macros that speak which tracks have a state, and on a double press reset it on all of them: solo, mute, record arm, input monitoring, the safe states, selection, shown and hidden tracks, and tracks that reached 0 dB.
enum TrackStatus {
    @MainActor
    static var macros: [Macro] { [
        flagMacro("floTools.speakSoloedTracksUnsoloAllTracks", "Speak Soloed Tracks, Unsolo All Tracks", key: "Opt+Shift+S", .soloed, Wording(none: "No tracks are soloed.", heading: "Soloed:"),
                  reset: Reset(suspendsGroups: true, partly: "Unsoloed", done: "unsoloed all tracks.")),
        flagMacro("floTools.speakMutedTracksUnmuteAllTracks", "Speak Muted Tracks, Unmute All Tracks", key: "Opt+Shift+M", .muted, Wording(none: "No tracks are muted.", heading: "Muted:"),
                  reset: Reset(suspendsGroups: true, partly: "Unmuted", done: "unmuted all tracks.")),
        flagMacro("floTools.speakInputMonitorEnabledTracksDisableInputMonitorOnAllTracks", "Speak Input Monitor-Enabled Tracks, Disable Input Monitor On All Tracks", key: "Opt+Shift+K", .inputMonitored, Wording(none: "No track has input monitor on", heading: "Input on:"),
                  reset: Reset(suspendsGroups: false, partly: "Turned off input monitor on", done: "Turned Off Input Monitor for all tracks")),
        recordArmed,
        flagMacro("floTools.speakRecordSafeTracks", "Speak Record Safe Tracks", key: "Opt+Shift+Cmd+R", .recordSafe, Wording(none: "No tracks are disarmed safe.", heading: "Disarmed safe:")),
        flagMacro("floTools.speakSoloSafeTracks", "Speak Solo Safe Tracks", key: "Opt+Shift+Cmd+S", .soloSafe, Wording(none: "No tracks are solo safe.", heading: "Solo safe:")),
        Macro("floTools.speakTracksWith0DbLevel", "Speak Tracks With 0DB Level", group: .floTools, triggers: [.key("Opt+Shift+0")]) { _ in
            try await speakTracksAt0dB()
        },
        Macro("floTools.speakSelectedTracksDeselectAllTracks", "Speak Selected Tracks, Deselect All Tracks", group: .floTools, triggers: [.key("Opt+Shift+L")], single: { _ in
            try await speak(.trackList(.selected, on: true), Wording(none: "No tracks are selected.", heading: "selected."))
        }, double: { _ in
            try await deselectAll()
        }),
        Macro("floTools.speakHiddenTracksShowTrackListPopUpMenu", "Speak Hidden Tracks, Show Track List Pop-up Menu", group: .floTools, triggers: [.key("Opt+Shift+H")], single: { _ in
            try await speak(.trackList(.shown, on: false), Wording(none: "No tracks are hidden.", heading: "Hidden:"))
        }, double: { _ in
            try await ProToolsApp.running().mixWindow().openTrackListMenu()
        }),
        Macro("floTools.speakShownTracksShowTrackListPopUpMenu", "Speak Shown Tracks, Show Track List Pop-up Menu", group: .floTools, triggers: [.key("Opt+Shift+W")], single: { _ in
            try await speak(.trackList(.shown, on: true), Wording(none: "No tracks are currently shown.", heading: "Shown:"))
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
        /// Starts the report of a run that failed part way, for example "Unsoloed 2 of 5 tracks".
        let partly: String
        /// Spoken when every track was handled.
        let done: String
    }

    @MainActor
    private static func flagMacro(_ id: MacroID, _ name: String, key: String, _ flag: TrackFlag, _ wording: Wording, reset: Reset? = nil) -> Macro {
        let speak: MacroBody = { _ in try await TrackStatus.speak(.strips(flag, on: true), wording) }
        guard let reset else {
            return Macro(id, name, group: .floTools, triggers: [.key(key)], body: speak)
        }
        return Macro(id, name, group: .floTools, triggers: [.key(key)], single: speak, double: { _ in
            try await resetAll(flag, reset)
            try await VoiceOver.say(reset.done)
        })
    }

    static func speak(_ tracks: TrackSet, _ wording: Wording) async throws {
        let names = try await tracks.names(in: ProToolsApp.running().mixWindow())
        try await VoiceOver.say(message(names: names, wording))
    }

    /// Record arm has two extra cases: armed tracks can be hidden, which only the Edit window's record status shows, as the JXA checked. The JXA disarmed in a loop until that status cleared, which never ended while a hidden track was armed; this disarms the shown tracks once and says when hidden ones stay armed.
    @MainActor
    private static var recordArmed: Macro {
        Macro("floTools.speakRecordEnabledTracksDisarmAllRecordEnabledTracks", "Speak Record-Enabled Tracks, Disarm All Record-Enabled Tracks", group: .floTools, triggers: [.key("Opt+Shift+R")], single: { _ in
            let proTools = try ProToolsApp.running()
            let names = try await proTools.mixWindow().tracks(.recordArmed, on: true).map(\.name)
            try await VoiceOver.say(names.isEmpty ? noArmedTracksText(proTools) : "\(names.count) Armed: " + list(names))
        }, double: { _ in
            let reset = Reset(suspendsGroups: false, partly: "Disarmed", done: "Disarmed all tracks.")
            try await resetAll(.recordArmed, reset)
            let hiddenStillArmed = try await ProToolsApp.running().hasArmedTracks()
            try await VoiceOver.say(hiddenStillArmed ? "Disarmed all shown tracks. Some hidden tracks are still armed." : reset.done)
        })
    }

    /// For an empty list of armed tracks: whether hidden tracks are armed.
    static func noArmedTracksText(_ proTools: ProToolsApp) async throws -> String {
        try await proTools.hasArmedTracks() ? "Some tracks are armed." : "No tracks are armed."
    }

    /// Turns `flag` off on every track that has it, folders last, as the JXA did for solo. Each track is checked again before its click, because a click on a folder or a grouped track can change others, and the click waits for the button to change before the next one. Mix groups are suspended meanwhile if `reset` says so, and resumed however the loop ends: done, failed or cancelled. A failure part way says how far it got.
    static func resetAll(_ flag: TrackFlag, _ reset: Reset) async throws {
        let proTools = try ProToolsApp.running()
        let mix = try await proTools.mixWindow()
        let tracks = try await mix.tracks(flag, on: true)
        let ordered = tracks.filter { !$0.isFolder } + tracks.filter(\.isFolder)
        let suspendGroups = reset.suspendsGroups && !ordered.isEmpty ? try await mix.hasActiveGroups() : false
        if suspendGroups { try await proTools.setGroups(suspended: true, in: mix) }
        // `defer` cannot await, so the loop's error is kept and thrown after the groups are resumed.
        var handled = 0
        var loopError: (any Error)?
        do {
            var lastSound = ContinuousClock.now
            for track in ordered {
                // A stop request ends the loop between clicks.
                try Task.checkCancellation()
                try await set(flag, on: track, to: false)
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

    /// Presses the flag's button if the track takes part and its state is not `on` yet, then waits for the button to change.
    @AccessibilityActor
    static func set(_ flag: TrackFlag, on track: TrackStrip, to on: Bool) async throws {
        guard let state = try track.has(flag), state != on else { return }
        let before = try track.state(of: flag.toggle)
        try track.button(flag.toggle).press()
        _ = try await ProToolsUpdate.reading(changedFrom: before) { try track.state(of: flag.toggle) }
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
            guard !strip.name.contains(" - MIDI Track") else { return false }
            return try strip.peakDecibels().map { $0 >= 0 } ?? false
        }.map(\.name)
    }

    // MARK: Track List

    /// Deselects each selected track in the Track List, after expanding the list if it is collapsed, as the JXA did. Pro Tools may take a moment to show the change, so the check waits briefly.
    @AccessibilityActor
    static func deselectAll() async throws {
        let mix = try ProToolsApp.running().mixWindow()
        try mix.expandTrackList()
        for row in try mix.trackList().rows() where row.isSelected {
            try Task.checkCancellation()
            try row.toggleSelected()
        }
        let stillSelected = try await ProToolsUpdate.reading(changedFrom: true) { try mix.trackList().rows().contains(where: \.isSelected) }
        try await VoiceOver.say(stillSelected ? "Please expand track list table." : "Deselected All Tracks.")
    }
}

/// The tracks a macro reports or lists.
enum TrackSet: Sendable {
    /// Shown tracks that take part in the flag and have it (`on`) or not.
    case strips(TrackFlag, on: Bool)
    /// Track List rows, hidden tracks included, that are selected or shown (`on`) or not.
    case trackList(TrackListProperty, on: Bool)

    enum TrackListProperty: Sendable { case selected, shown }

    /// The tracks' names in window order.
    @AccessibilityActor
    func names(in mix: MixWindow) throws -> [String] {
        switch self {
        case .strips(let flag, let on): try mix.tracks(flag, on: on).map(\.name)
        case .trackList(let property, let on): try mix.trackList().rows().filter { $0.value(property) == on }.map(\.name)
        }
    }
}

extension TrackList.Row {
    @AccessibilityActor
    func value(_ property: TrackSet.TrackListProperty) -> Bool {
        switch property {
        case .selected: isSelected
        case .shown: isShown
        }
    }
}
