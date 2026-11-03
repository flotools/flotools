/// The sentences for an empty list of tracks that more than one command speaks: a status report, the track list of the same state and, for selected tracks, the playlist announcement. One definition, so they cannot drift apart. The words are the JXA's.
enum NoTracks {
    static let soloed = "No tracks are soloed."
    static let muted = "No tracks are muted."
    static let armed = "No tracks are armed."
    static let selected = "No tracks are selected."
    static let hidden = "No tracks are hidden."
    static let shown = "No tracks are currently shown."
}
