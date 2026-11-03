import Foundation
import FloEngine
import FloProTools
import FloSystem

/// The List macros: each shows the tracks in one state in a chooser, and changes the chosen ones, for example List Muted Tracks unmutes the chosen tracks. "List Tracks with Flo Tools" (Ctrl+Opt+Shift+L) offers them in a chooser, as the KM version showed them in a palette; they have no hotkeys of their own.
enum TrackLists {
    /// One List macro. The words are the JXA's.
    struct Listing: Sendable {
        let id: MacroID
        let name: String
        /// The listed tracks; choosing one switches the flag or presses the row's button.
        let source: TrackSet
        /// Spoken instead of opening an empty list.
        let none: String
        /// Follows the number of tracks in the window title, for example "3 Muted".
        let heading: String
        let prompt: String
        let okTitle: String
    }

    static let listings: [Listing] = [
        Listing(id: "floTools.listHiddenTracks", name: "List Hidden Tracks", source: .trackList(.shown, on: false), none: "No tracks are hidden.", heading: "hidden", prompt: "Choose tracks to show.", okTitle: "Show"),
        Listing(id: "floTools.listInputMonitorDisabledTracks", name: "List Input Monitor-Disabled  Tracks", source: .strips(.inputMonitored, on: false), none: "No tracks are input monitor disabled.", heading: "input monitor Disabled", prompt: "Choose tracks to enable input monitor.", okTitle: "Enable Input Monitor"),
        Listing(id: "floTools.listInputMonitorEnabledTracks", name: "List Input Monitor-Enabled Tracks", source: .strips(.inputMonitored, on: true), none: "No tracks are input monitor enabled.", heading: "Input Monitor Enabled.", prompt: "Choose tracks to disable input monitor.", okTitle: "Disable Input Monitor"),
        Listing(id: "floTools.listMutedTracks", name: "List Muted Tracks", source: .strips(.muted, on: true), none: "No tracks are muted.", heading: "Muted", prompt: "Choose tracks to unmute.", okTitle: "Unmute"),
        // The JXA put "<n> disarmed. Choose tracks to arm." in the prompt, with no title or OK name, and spoke nothing for an empty list; this follows the other lists.
        Listing(id: "floTools.listRecordDisabledTracks", name: "List Record-Disabled Tracks", source: .strips(.recordArmed, on: false), none: "No tracks are disarmed.", heading: "disarmed", prompt: "Choose tracks to arm.", okTitle: "Arm"),
        // An empty list is spoken by `TrackStatus.noArmedTracksText`, which knows about armed hidden tracks.
        Listing(id: "floTools.listRecordEnabledTracks", name: "List Record-Enabled Tracks", source: .strips(.recordArmed, on: true), none: "No tracks are armed.", heading: "armed", prompt: "Choose tracks to disarm.", okTitle: "Disarm"),
        Listing(id: "floTools.listSelectedTracks", name: "List Selected Tracks", source: .trackList(.selected, on: true), none: "No tracks are selected.", heading: "Selected", prompt: "Choose tracks to deselect.", okTitle: "Deselect"),
        Listing(id: "floTools.listShownTracks", name: "List Shown Tracks", source: .trackList(.shown, on: true), none: "No tracks are currently shown.", heading: "Shown", prompt: "Choose tracks to hide.", okTitle: "Hide"),
        Listing(id: "floTools.listSoloedTracks", name: "List Soloed Tracks", source: .strips(.soloed, on: true), none: "No tracks are soloed.", heading: "Soloed", prompt: "Choose tracks to unsolo.", okTitle: "Unsolo"),
        // The JXA showed the list but did not mute the chosen tracks; this mutes them.
        Listing(id: "floTools.listUnmutedTracks", name: "List Unmuted Tracks", source: .strips(.muted, on: false), none: "No tracks are unmuted.", heading: "Unmuted", prompt: "Choose tracks to mute.", okTitle: "Mute"),
        Listing(id: "floTools.listUnselectedTracks", name: "List Unselected Tracks", source: .trackList(.selected, on: false), none: "No tracks are unselected.", heading: "Unselected", prompt: "Choose tracks to select.", okTitle: "Select"),
        Listing(id: "floTools.listUnsoloedTracks", name: "List Unsoloed Tracks", source: .strips(.soloed, on: false), none: "No tracks are unsoloed.", heading: "Unsoloed", prompt: "Choose tracks to solo.", okTitle: "Solo"),
    ]

    @MainActor
    static var macros: [Macro] {
        listings.map { listing in
            Macro(listing.id, listing.name, scope: .anyProToolsWindow, triggers: []) { _ in try await run(listing) }
        } + [chooseList]
    }

    /// The KM version spoke "Choose what to list.", paused 1 s and showed a palette. The chooser's prompt says the same and VoiceOver reads it when the window opens, so there is no separate speech or pause.
    @MainActor
    private static var chooseList: Macro {
        Macro("floTools.listTracksWithFloTools", "List Tracks with Flo Tools", scope: .anyProToolsWindow, triggers: [.key("Ctrl+Opt+Shift+L")]) { run in
            let request = Chooser.Request(title: "List Tracks with Flo Tools", prompt: "Choose what to list.", items: listings.map(\.name), okTitle: "List", allowsMultipleSelection: false)
            // The chosen list opens a second chooser; holding the focus keeps it from going back to Pro Tools in between.
            try await BorrowedFocus.holding {
                guard let chosen = await Chooser.choose(request).first else { return }
                try await run.run(listings[chosen].id)
            }
        }
    }

    static func run(_ listing: Listing) async throws {
        let proTools = try ProToolsApp.running()
        let names = try await listing.source.names(in: proTools.mixWindow())
        guard !names.isEmpty else {
            let isArmedList: Bool = if case .strips(.recordArmed, on: true) = listing.source { true } else { false }
            try await VoiceOver.say(isArmedList ? TrackStatus.noArmedTracksText(proTools) : listing.none)
            return
        }
        let request = Chooser.Request(title: "\(names.count) \(listing.heading)", prompt: listing.prompt, items: names.map(displayName), okTitle: listing.okTitle)
        let chosen = await Chooser.choose(request).map { names[$0] }
        try Task.checkCancellation()
        try await apply(listing.source, to: chosen, proTools)
    }

    /// Without the trailing space Pro Tools puts after "Track".
    static func displayName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces)
    }

    /// Changes each chosen track that is still in the listed state. The lists were read before the user chose, so a track may have changed or gone since; those are skipped.
    @AccessibilityActor
    private static func apply(_ source: TrackSet, to chosen: [String], _ proTools: ProToolsApp) async throws {
        guard !chosen.isEmpty else { return }
        let mix = try proTools.mixWindow()
        switch source {
        case .strips(let flag, let on):
            for name in chosen {
                try Task.checkCancellation()
                guard let track = try mix.track(named: name) else { continue }
                try await TrackStatus.set(flag, on: track, to: !on)
            }
        case .trackList(let property, let on):
            let rows = try mix.trackList().rows()
            for name in chosen {
                try Task.checkCancellation()
                guard let row = rows.first(where: { $0.name == name }), row.value(property) == on else { continue }
                switch property {
                case .selected: try row.toggleSelected()
                case .shown: try row.toggleShown()
                }
            }
        }
    }
}
