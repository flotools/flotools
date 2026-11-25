import FloSystem

/// A set of tracks by state, which the track reports read and the track lists change.
public enum TrackQuery: Sendable, Equatable {
    /// Shown tracks that take part in the flag and have it (`on`) or not.
    case strips(TrackFlag, on: Bool)
    /// Shown frozen tracks, read through the Edit window.
    case shownFrozen
    /// Track List rows, hidden tracks included, that are selected or shown (`on`) or not.
    case trackList(TrackList.Property, on: Bool)
}

extension ProToolsApp {
    /// The names of the tracks in `query`, in window order.
    @AccessibilityActor
    public func names(_ query: TrackQuery) throws -> [String] {
        switch query {
        case .shownFrozen: try shownFrozenTracks().frozen.map(\.name)
        case .strips(let flag, let on): try mixWindow().tracks(flag, on: on).map(\.name)
        case .trackList(let property, let on): try mixWindow().trackList().rows(property, on: on).map(\.name)
        }
    }

    /// Moves each named track that is still in `query` out of it, for example unmutes the named tracks that are muted. The names were usually read earlier, so a track that has changed or gone since is skipped. Returns the names of strips whose flag did not change, such as a track without an input that Pro Tools refuses to arm. Track List rows are pressed without waiting for them.
    @AccessibilityActor
    public func change(_ names: [String], outOf query: TrackQuery) async throws -> [String] {
        var unchanged: [String] = []
        switch query {
        case .shownFrozen:
            let tracks = try shownFrozenTracks().frozen
            for name in names {
                try Task.checkCancellation()
                guard let track = tracks.first(where: { $0.name == name }) else { continue }
                if try await !track.unfreeze() { unchanged.append(name) }
            }
        case .strips(let flag, let on):
            let mix = try mixWindow()
            for name in names {
                try Task.checkCancellation()
                guard let track = try mix.track(named: name) else { continue }
                if try await !track.set(flag, to: !on) { unchanged.append(name) }
            }
        case .trackList(let property, let on):
            let rows = try mixWindow().trackList().rows(property, on: on)
            for name in names {
                try Task.checkCancellation()
                guard let row = rows.first(where: { $0.name == name }) else { continue }
                try row.toggle(property)
            }
        }
        return unchanged
    }
}
