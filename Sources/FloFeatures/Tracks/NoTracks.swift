/// The sentences for an empty list of tracks that more than one command speaks: a status report, the track list of the same state and, for selected tracks, the playlist announcement. One definition, so they cannot drift apart. The existing states keep the JXA’s words; frozen tracks use the Swift freeze report’s words.
enum NoTracks {
    static let frozen = "No shown tracks are frozen."
    static let soloed = "No tracks are soloed."
    static let muted = "No tracks are muted."
    static let armed = "No tracks are armed."
    static let selected = "No tracks are selected."
    static let hidden = "No tracks are hidden."
    static let shown = "No tracks are currently shown."
}
