import CoreGraphics
import FloEngine
import FloProTools
import FloSystem

/// Flo Tools commands for Pro Tools windows as a whole: closing floating windows, opening Preferences, putting the mouse on a table's resize edge, and speaking the selected clips.
enum WindowTools {
    @MainActor
    static var commands: [Command] { [
        Command("floTools.closeAllFloatingWindows", "Close All Floating Windows", summary: "Presses the close button of every Pro Tools window except the Mix and Edit windows. Windows without one, such as dialogs, stay open.", scope: .anyProToolsWindow, triggers: [.key("Opt+Cmd+W")]) { _ in
            try await ProToolsApp.running().closeFloatingWindows()
        },
        Command("floTools.openPreferencesDialog", "Open Preferences Dialog", summary: "Opens Setup > Preferences in Pro Tools.", scope: .anyProToolsWindow, triggers: [.key("Opt+Cmd+,")]) { _ in
            try await ProToolsApp.running().control(.menuItem(menu: "Setup", .contains("Preferences"))).press()
        },
        resizeTable("floTools.resizeClipsTable", "Resize Clips Table", "the Edit window's clip list", key: "Ctrl+Shift+Cmd+C", .editClips),
        resizeTable("floTools.resizeTrackListTable", "Resize Track List Table", "the front window's Track List", key: "Ctrl+Shift+Cmd+T", .frontTrackList),
        Command("floTools.speakSelectedClips", "Speak Selected Clips", summary: "Speaks the clips selected in the clip list.", scope: .anyProToolsWindow, triggers: [.key("Opt+Shift+,")]) { _ in
            try await VoiceOver.say(selectedClipsText(try await ProToolsApp.running().selectedClipNames()))
        },
    ] }

    /// Speaks the table's width and moves the mouse onto its resize edge, so the user can drag it: just left of the Clips table's top-left corner, or right of the Track List, as the KM version placed it.
    @MainActor
    private static func resizeTable(_ id: CommandID, _ name: String, _ what: String, key: String, _ table: ProToolsApp.Table) -> Command {
        Command(id, name, summary: "Speaks the width of \(what) and moves the mouse onto its resize edge, ready to drag.", scope: .anyProToolsWindow, triggers: [.key(key)]) { _ in
            let proTools = try ProToolsApp.running()
            let frame = try await proTools.frame(of: table)
            try await VoiceOver.say(resizeText(table, width: frame.width))
            try Mouse.move(to: resizeEdge(table, frame), ifFront: proTools.pid)
        }
    }

    static func resizeEdge(_ table: ProToolsApp.Table, _ frame: CGRect) -> CGPoint {
        switch table {
        case .editClips: CGPoint(x: frame.minX - 1, y: frame.minY - 3)
        case .frontTrackList: CGPoint(x: frame.maxX + 16, y: frame.minY)
        }
    }

    static func resizeText(_ table: ProToolsApp.Table, width: CGFloat) -> String {
        let name = switch table {
        case .editClips: "Clips table"
        case .frontTrackList: "Track list table"
        }
        return "\(name) is \(Int(width.rounded())) points wide. Click and drag to resize."
    }

    /// `2 Selected: "Kick_01","Snare_02"`: the JXA joined the quoted names with commas, as JavaScript prints a list.
    static func selectedClipsText(_ names: [String]) -> String {
        names.isEmpty ? "No clips are currently selected." : "\(names.count) Selected: " + names.joined(separator: ",")
    }
}
