import FloProTools

/// Where a command's keys work: in any Pro Tools window, in windows of some kinds, or on the track under the VoiceOver cursor. Every key is taken only while Pro Tools is in front.
public enum Scope: Sendable, Equatable {
    /// Any Pro Tools window, also while no window or no title is known.
    case anyProToolsWindow
    case windows(Set<ProToolsWindowKind>)
    /// The track whose name the VoiceOver cursor is on, in the Mix or Edit window. Only a press can tell, so the engine checks the cursor at each press before it runs the command; when the cursor is not on a track, the key goes to the next command that has it, or on to Pro Tools.
    case trackUnderVoiceOverCursor

    public static let mixOrEdit = Scope.windows([.mix, .edit])

    /// The window kinds the scope is limited to, or nil for any Pro Tools window.
    var windowKinds: Set<ProToolsWindowKind>? {
        switch self {
        case .anyProToolsWindow: nil
        case .windows(let kinds): kinds
        case .trackUnderVoiceOverCursor: [.mix, .edit]
        }
    }

    /// Whether the front window allows the scope. For `trackUnderVoiceOverCursor` the cursor is checked later, at the press.
    public func applies(to context: FrontContext) -> Bool {
        guard context.bundleID == ProToolsApp.bundleID else { return false }
        guard let kinds = windowKinds else { return true }
        guard let kind = context.proToolsWindowKind else { return false }
        return kinds.contains(kind)
    }

    /// Whether the scope is limited to windows of some kinds, so its commands belong to those windows rather than to Pro Tools as a whole.
    public var isLimitedToWindowKinds: Bool {
        windowKinds != nil
    }

    /// The more specific scope wins when both have the key: a track over its window, a window kind over any window.
    var precedence: Int {
        switch self {
        case .anyProToolsWindow: 0
        case .windows: 1
        case .trackUnderVoiceOverCursor: 2
        }
    }

    /// Whether some front window is in both scopes.
    func overlaps(_ other: Scope) -> Bool {
        guard let a = windowKinds, let b = other.windowKinds else { return true }
        return !a.isDisjoint(with: b)
    }
}
