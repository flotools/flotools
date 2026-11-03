import FloSystem

/// A set of tracks by state, which the track reports read and the track lists change.
public enum TrackQuery: Sendable, Equatable {
    /// Shown tracks that take part in the flag and have it (`on`) or not.
    case strips(TrackFlag, on: Bool)
    /// Track List rows, hidden tracks included, that are selected or shown (`on`) or not.
    case trackList(TrackList.Property, on: Bool)
}

extension MixWindow {
    /// The names of the tracks in `query`, in window order.
    public func names(_ query: TrackQuery) throws -> [String] {
        switch query {
        case .strips(let flag, let on): try tracks(flag, on: on).map(\.name)
        case .trackList(let property, let on): try trackList().rows().filter { $0.has(property) == on }.map(\.name)
        }
    }

    /// Moves each named track that is still in `query` out of it, for example unmutes the named tracks that are muted. The names were usually read earlier, so a track that has changed or gone since is skipped. Returns the names of strips whose flag did not change, such as a track without an input that Pro Tools refuses to arm. Track List rows are pressed without waiting for them.
    public func change(_ names: [String], outOf query: TrackQuery) async throws -> [String] {
        var unchanged: [String] = []
        switch query {
        case .strips(let flag, let on):
            for name in names {
                try Task.checkCancellation()
                guard let track = try track(named: name) else { continue }
                if try await !track.set(flag, to: !on) { unchanged.append(name) }
            }
        case .trackList(let property, let on):
            let rows = try trackList().rows()
            for name in names {
                try Task.checkCancellation()
                guard let row = rows.first(where: { $0.name == name }), row.has(property) == on else { continue }
                try row.toggle(property)
            }
        }
        return unchanged
    }
}
