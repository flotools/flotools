import FloEngine
import FloProTools
import FloSystem

enum TrackMovement {
    @MainActor
    static var commands: [Command] { [
        command(.earlier, id: "tracks.moveEarlier", name: "Move Selected Tracks Up or Left", key: "Ctrl+Shift+Cmd+P"),
        command(.later, id: "tracks.moveLater", name: "Move Selected Tracks Down or Right", key: "Ctrl+Shift+Cmd+;"),
    ] }

    @MainActor
    private static func command(_ direction: TrackMoveDirection, id: CommandID, name: String, key: String) -> Command {
        Command(id, name,
                summary: "Moves selected tracks one position \(direction == .earlier ? "earlier" : "later"), preserving their order and selection, and speaks the result. Nonadjacent selections gather into one block. Reveals the source and destination with Scroll Into View. Requires a Track List without folders.",
                scope: .windows([.mix, .edit]), triggers: [.key(key)]) { run in
            try await Keyboard.waitForModifiersReleased()
            let result = try await ProToolsApp.running().moveSelectedTracks(direction)
            try await VoiceOver.say(text(result, direction: direction, inMix: run.context.proToolsWindowKind == .mix))
        }
    }

    static func text(_ result: TrackMoveResult, direction: TrackMoveDirection, inMix: Bool) -> String {
        switch result {
        case .noSelection: return NoTracks.selected
        case .atBoundary:
            return direction == .earlier
                ? "The first selected track is already at the beginning of the Track List."
                : "The last selected track is already at the end of the Track List."
        case .moved(let count, let position):
            let movement = inMix ? (direction == .earlier ? "left" : "right") : (direction == .earlier ? "up" : "down")
            return "Moved \(count) \(count == 1 ? "track" : "tracks") \(movement), position \(position)."
        }
    }
}
