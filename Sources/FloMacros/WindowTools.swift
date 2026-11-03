import CoreGraphics
import FloEngine
import FloProTools
import FloSystem

/// Flo Tools macros for Pro Tools windows as a whole: closing floating windows, opening Preferences, putting the mouse on a table's resize edge, and speaking the selected clips.
enum WindowTools {
    @MainActor
    static var macros: [Macro] { [
        Macro("floTools.closeAllFloatingWindows", "Close All Floating Windows", group: .floTools, triggers: [.key("Opt+Cmd+W")]) { _ in
            _ = try await ProToolsApp.running().closeFloatingWindows()
        },
        Macro("floTools.openPreferencesDialog", "Open Preferences Dialog", group: .floTools, triggers: [.key("Opt+Cmd+,")]) { _ in
            try await ProToolsApp.running().control(.menuItem(menu: "Setup", .contains("Preferences"))).press()
        },
        resizeTable("floTools.resizeClipsTable", "Resize Clips Table", key: "Ctrl+Shift+Cmd+C", .editClips),
        resizeTable("floTools.resizeTrackListTable", "Resize Track LIst Table", key: "Ctrl+Shift+Cmd+T", .frontTrackList),
        Macro("floTools.speakSelectedClips", "Speak Selected Clips", group: .floTools, triggers: [.key("Opt+Shift+,")]) { _ in
            try await VoiceOver.say(selectedClipsText(try await ProToolsApp.running().selectedClipNames()))
        },
    ] }

    /// Speaks the table's width and moves the mouse onto its resize edge, so the user can drag it: just left of the Clips table's top-left corner, or right of the Track List, as the KM version placed it.
    @MainActor
    private static func resizeTable(_ id: MacroID, _ name: String, key: String, _ table: ProToolsApp.Table) -> Macro {
        Macro(id, name, group: .floTools, triggers: [.key(key)]) { _ in
            let frame = try await ProToolsApp.running().frame(of: table)
            try await VoiceOver.say(resizeText(table, width: frame.width))
            Mouse.move(to: resizeEdge(table, frame))
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
