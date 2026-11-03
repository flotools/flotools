/// The kind of a track, from the name Pro Tools gives its strip and Track List row: the user's track name, " - ", the kind and " Track ", for example "Kick - Audio Track " or "Drums - Routing Folder Track ". Only the part after the last " - " is read, so a user's track name that mentions a kind does not count.
public enum TrackKind: Sendable, Equatable {
    case audio, midi, instrument, aux, master, folder
    /// Any other kind, such as VCA or video, or a name without the suffix.
    case other

    public init(trackName: String) {
        guard let separator = trackName.range(of: " - ", options: .backwards) else {
            self = .other
            return
        }
        let suffix = trackName[separator.upperBound...].trimmingCharacters(in: .whitespaces).lowercased()
        self = switch suffix {
        case "audio track": .audio
        case "midi track": .midi
        case "inst track", "instrument track": .instrument
        // The JXA matched both spellings.
        case "aux track", "auxiliary track": .aux
        case "master track": .master
        case _ where suffix.hasSuffix("folder track"): .folder
        default: .other
        }
    }
}
