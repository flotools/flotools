import Foundation

/// What kind of Pro Tools window is in front, decided from its title. Every title is exactly one kind, so two key bindings for different kinds can never both apply, and the order of the checks below is the only rule for titles that fit two descriptions.
public enum ProToolsWindowKind: Sendable, Hashable, CustomStringConvertible {
    case mix
    case edit
    case plugIn
    case audioSuite
    case fade(FadeDialog.Kind)
    /// A window with setup tabs that Cmd+1 to 9 pick: I/O Setup, Peripherals, Preferences, Dashboard.
    case tabbedSetup
    case other

    /// Words that mark a tabbed setup window anywhere in its title, as in the KM Selected Tab group.
    static let tabbedSetupWords = ["I/O Setup", "Peripherals", "Preferences", "Dashboard"]

    /// Classifies a title. Comparisons ignore case, as Keyboard Maestro's did. Mix and Edit come first, so a session named "Dashboard" stays a Mix window; a plug-in window comes before AudioSuite, so "Plug-in: Audio Suite: X" is a plug-in window.
    public init(title: String) {
        func starts(with prefix: String) -> Bool { title.range(of: prefix, options: [.anchored, .caseInsensitive]) != nil }
        func contains(_ text: String) -> Bool { title.range(of: text, options: .caseInsensitive) != nil }

        if starts(with: ProToolsApp.TrackWindow.mix.rawValue + ":") {
            self = .mix
        } else if starts(with: ProToolsApp.TrackWindow.edit.rawValue + ":") {
            self = .edit
        } else if starts(with: PlugInWindow.Kind.plugIn.titlePrefix) {
            self = .plugIn
        } else if contains(PlugInWindow.Kind.audioSuite.titlePrefix) {
            self = .audioSuite
        } else if let fade = FadeDialog.Kind.allCases.first(where: { title.caseInsensitiveCompare($0.rawValue) == .orderedSame }) {
            self = .fade(fade)
        } else if Self.tabbedSetupWords.contains(where: contains) {
            self = .tabbedSetup
        } else {
            self = .other
        }
    }

    /// For the log and the keymap baseline.
    public var description: String {
        switch self {
        case .mix: "Mix"
        case .edit: "Edit"
        case .plugIn: "Plug-in"
        case .audioSuite: "AudioSuite"
        case .fade(let kind): kind.rawValue
        case .tabbedSetup: "setup tabs"
        case .other: "other"
        }
    }
}
