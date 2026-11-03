import Foundation
import FloEngine
import FloProTools
import FloSystem

/// The track lists: each shows the tracks in one state in a chooser, and changes the chosen ones, for example List Muted Tracks unmutes the chosen tracks. "List Tracks with Flo Tools" (Ctrl+Opt+Shift+L) offers them in a chooser, as the KM version showed them in a palette. In the KM version each list was a macro without a hotkey; here they are only the chooser's choices.
enum TrackLists {
    /// One list, named as its KM macro was. The words are the JXA's.
    struct Listing: Sendable {
        let name: String
        /// The listed tracks; choosing one switches the flag or presses the row's button.
        let source: TrackQuery
        /// Spoken instead of opening an empty list.
        let none: String
        /// Follows the number of tracks in the window title, for example "3 Muted".
        let heading: String
        let prompt: String
        let okTitle: String
    }

    static let listings: [Listing] = [
        Listing(name: "List Hidden Tracks", source: .trackList(.shown, on: false), none: "No tracks are hidden.", heading: "hidden", prompt: "Choose tracks to show.", okTitle: "Show"),
        Listing(name: "List Input Monitor-Disabled  Tracks", source: .strips(.inputMonitored, on: false), none: "No tracks are input monitor disabled.", heading: "input monitor Disabled", prompt: "Choose tracks to enable input monitor.", okTitle: "Enable Input Monitor"),
        Listing(name: "List Input Monitor-Enabled Tracks", source: .strips(.inputMonitored, on: true), none: "No tracks are input monitor enabled.", heading: "Input Monitor Enabled.", prompt: "Choose tracks to disable input monitor.", okTitle: "Disable Input Monitor"),
        Listing(name: "List Muted Tracks", source: .strips(.muted, on: true), none: "No tracks are muted.", heading: "Muted", prompt: "Choose tracks to unmute.", okTitle: "Unmute"),
        // The JXA put "<n> disarmed. Choose tracks to arm." in the prompt, with no title or OK name, and spoke nothing for an empty list; this follows the other lists.
        Listing(name: "List Record-Disabled Tracks", source: .strips(.recordArmed, on: false), none: "No tracks are disarmed.", heading: "disarmed", prompt: "Choose tracks to arm.", okTitle: "Arm"),
        // An empty list is spoken by `TrackStatus.noArmedTracksText`, which knows about armed hidden tracks.
        Listing(name: "List Record-Enabled Tracks", source: .strips(.recordArmed, on: true), none: "No tracks are armed.", heading: "armed", prompt: "Choose tracks to disarm.", okTitle: "Disarm"),
        Listing(name: "List Selected Tracks", source: .trackList(.selected, on: true), none: "No tracks are selected.", heading: "Selected", prompt: "Choose tracks to deselect.", okTitle: "Deselect"),
        Listing(name: "List Shown Tracks", source: .trackList(.shown, on: true), none: "No tracks are currently shown.", heading: "Shown", prompt: "Choose tracks to hide.", okTitle: "Hide"),
        Listing(name: "List Soloed Tracks", source: .strips(.soloed, on: true), none: "No tracks are soloed.", heading: "Soloed", prompt: "Choose tracks to unsolo.", okTitle: "Unsolo"),
        // The JXA showed the list but did not mute the chosen tracks; this mutes them.
        Listing(name: "List Unmuted Tracks", source: .strips(.muted, on: false), none: "No tracks are unmuted.", heading: "Unmuted", prompt: "Choose tracks to mute.", okTitle: "Mute"),
        Listing(name: "List Unselected Tracks", source: .trackList(.selected, on: false), none: "No tracks are unselected.", heading: "Unselected", prompt: "Choose tracks to select.", okTitle: "Select"),
        Listing(name: "List Unsoloed Tracks", source: .strips(.soloed, on: false), none: "No tracks are unsoloed.", heading: "Unsoloed", prompt: "Choose tracks to solo.", okTitle: "Solo"),
    ]

    @MainActor
    static var macros: [Macro] { [chooseList] }

    /// The KM version spoke "Choose what to list.", paused 1 s and showed a palette. The chooser's prompt says the same and VoiceOver reads it when the window opens, so there is no separate speech or pause.
    @MainActor
    private static var chooseList: Macro {
        Macro("floTools.listTracksWithFloTools", "List Tracks with Flo Tools", scope: .anyProToolsWindow, triggers: [.key("Ctrl+Opt+Shift+L")]) { _ in
            let request = Chooser.Request(title: "List Tracks with Flo Tools", prompt: "Choose what to list.", items: listings.map(\.name), okTitle: "List", allowsMultipleSelection: false)
            // The chosen list opens a second chooser; holding the focus keeps it from going back to Pro Tools in between.
            try await BorrowedFocus.holding {
                guard let chosen = await Chooser.choose(request).first else { return }
                Log.info(.engine, "chose \(listings[chosen].name)")
                try await show(listings[chosen])
            }
        }
    }

    /// Shows the listed tracks in a chooser and changes the chosen ones, or says there are none.
    static func show(_ listing: Listing) async throws {
        let proTools = try ProToolsApp.running()
        let names = try await proTools.mixWindow().names(listing.source)
        guard !names.isEmpty else {
            let isArmedList: Bool = if case .strips(.recordArmed, on: true) = listing.source { true } else { false }
            try await VoiceOver.say(isArmedList ? TrackStatus.noArmedTracksText(proTools) : listing.none)
            return
        }
        let request = Chooser.Request(title: "\(names.count) \(listing.heading)", prompt: listing.prompt, items: names.map(displayName), okTitle: listing.okTitle)
        let chosen = await Chooser.choose(request).map { names[$0] }
        try Task.checkCancellation()
        guard !chosen.isEmpty else { return }
        let unchanged = try await proTools.mixWindow().change(chosen, outOf: listing.source)
        // The JXA did not check; a track Pro Tools refused, such as one without an input to arm, is named rather than passed over in silence.
        guard unchanged.isEmpty else { throw FloError.couldNot(unchangedText(listing, unchanged)) }
    }

    /// For example "arm: Kick - Audio Track, Snare - Audio Track", after "Could not".
    static func unchangedText(_ listing: Listing, _ names: [String]) -> String {
        listing.okTitle.lowercased() + ": " + names.map(displayName).joined(separator: ", ")
    }

    /// Without the trailing space Pro Tools puts after "Track".
    static func displayName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces)
    }
}
