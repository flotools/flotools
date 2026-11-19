import FloEngine
import FloProTools
import FloSystem

enum NewTracksAnnouncements {
    @MainActor
    static var commands: [Command] { [
        setting(.format, id: "format", name: "Format", keys: ["Cmd+Left", "Cmd+Right"]),
        setting(.type, id: "type", name: "Type", keys: ["Cmd+Up", "Cmd+Down"]),
        setting(.timebase, id: "timebase", name: "Timebase", keys: ["Opt+Cmd+Up", "Opt+Cmd+Down"]),
        Command("newTracks.rows", "Announce New Tracks Row Count",
                summary: "Passes the add or remove row shortcut to New Tracks and speaks the resulting number of track-entry rows.",
                scope: .windows([.newTracks]),
                triggers: ["Shift+Cmd+=", "Cmd+-", "Cmd+Keypad +", "Cmd+Keypad -", "Shift+Cmd+Up", "Shift+Cmd+Down"].map { .key($0) }) { run in
            try await KeyAnnouncements.announceChange(run, when: .always, within: ProToolsUpdate.passedKeyTimeout,
                find: { try ProToolsApp.running().newTracksDialog() }, read: { try $0.rowCount() },
                spoken: { _, count in
                    // A removed row moves keyboard focus; let VoiceOver finish its native focus feedback first.
                    try await Task.sleep(for: .milliseconds(100))
                    return rowCountText(count)
                })
        },
    ] }

    @MainActor
    private static func setting(_ setting: NewTracksDialog.Setting, id: String, name: String, keys: [String]) -> Command {
        Command(CommandID("newTracks.\(id)"), "Announce New Tracks \(name)",
                summary: "Passes the key to New Tracks and speaks the resulting track \(name.lowercased()). With multiple rows, identifies the changed row.",
                scope: .windows([.newTracks]), triggers: keys.map { .key($0) }) { run in
            try await KeyAnnouncements.announceChange(run, when: .always, within: ProToolsUpdate.passedKeyTimeout,
                find: { try ProToolsApp.running().newTracksDialog() }, read: { try $0.values(for: setting) },
                spoken: selectionText)
        }
    }

    /// At a list boundary nothing changes; reading all rows avoids guessing which row received the shortcut.
    static func selectionText(before: [String]?, after: [String]) -> String {
        guard after.count != 1 else { return after[0] }
        let changed = after.indices.filter { index in
            guard let before, before.indices.contains(index) else { return true }
            return before[index] != after[index]
        }
        let rows = changed.isEmpty ? Array(after.indices) : changed
        return rows.map { "Row \($0 + 1), \(after[$0])" }.joined(separator: ". ")
    }

    static func rowCountText(_ count: Int) -> String {
        "\(count) track \(count == 1 ? "row" : "rows")"
    }
}
