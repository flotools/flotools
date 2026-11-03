import FloProTools

/// Where a macro's keys work: in any Pro Tools window, or only in windows of some kinds. Every key is taken only while Pro Tools is in front.
public enum Scope: Sendable, Equatable {
    /// Any Pro Tools window, also while no window or no title is known.
    case anyProToolsWindow
    case windows(Set<ProToolsWindowKind>)

    public static let mixOrEdit = Scope.windows([.mix, .edit])

    public func applies(to context: FrontContext) -> Bool {
        guard context.bundleID == ProToolsApp.bundleID else { return false }
        switch self {
        case .anyProToolsWindow: return true
        case .windows(let kinds):
            guard let kind = context.proToolsWindowKind else { return false }
            return kinds.contains(kind)
        }
    }

    /// A scope for some window kinds wins over an any-window scope when both have the key.
    var precedence: Int {
        switch self {
        case .anyProToolsWindow: 0
        case .windows: 1
        }
    }

    /// Whether some front window is in both scopes.
    func overlaps(_ other: Scope) -> Bool {
        switch (self, other) {
        case (.windows(let a), .windows(let b)): !a.isDisjoint(with: b)
        default: true
        }
    }
}

/// App state that decides which keys apply, beside the front window. So far only the Flo Tools Inspector: while it is on, plain keys such as S act on the track under the VoiceOver cursor.
public struct Mode: Sendable, Equatable {
    public var inspector = false

    public init(inspector: Bool = false) {
        self.inspector = inspector
    }
}

/// The mode a macro's keys need.
public enum ModeCondition: Sendable, Equatable {
    case any
    case inspectorOn
    case inspectorOff

    public func holds(in mode: Mode) -> Bool {
        switch self {
        case .any: true
        case .inspectorOn: mode.inspector
        case .inspectorOff: !mode.inspector
        }
    }

    /// Whether some mode meets both conditions.
    func overlaps(_ other: ModeCondition) -> Bool {
        self == .any || other == .any || self == other
    }
}
