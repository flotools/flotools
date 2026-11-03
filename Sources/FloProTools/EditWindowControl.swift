import FloSystem

/// How an element is picked by its name. Some names change with the state, such as the Grid mode button ("Absolute Grid mode", "Relative Grid mode") or Track > "Set Record Tracks to Input Only".
public enum NameMatch: Sendable, Equatable {
    case `is`(String)
    case contains(String)

    func matches(_ name: String?) -> Bool {
        guard let name else { return false }
        return switch self {
        case .is(let text): name == text
        case .contains(let text): name.contains(text)
        }
    }

    var text: String {
        switch self {
        case .is(let text), .contains(let text): text
        }
    }
}

/// A control in the Edit window's toolbar, such as the Main Counter text field in "Counter Display Cluster" or the Pre-roll Amount in "Transport View Cluster" > "Transport Display".
public struct EditWindowControl: Sendable, Equatable {
    /// Group names from the window down to the group that holds the control.
    public let groups: [String]
    /// The control's AX role, for example "AXTextField".
    public let role: String
    public let name: NameMatch

    public init(_ groups: [String], role: String, _ name: NameMatch) {
        self.groups = groups
        self.role = role
        self.name = name
    }
}

extension ProToolsApp {
    /// The element of `control` in the Edit window, or `FloError.notFound` naming the missing step.
    @AccessibilityActor
    public func element(_ control: EditWindowControl) throws -> AXElement {
        var parent = try window(titlePrefix: "Edit:", "the Edit window")
        for group in control.groups {
            parent = try parent.required("the \(group)") { try $0.group(group) }
        }
        return try parent.required("the \(control.name.text)") { try $0.children(role: control.role).first { try control.name.matches($0.name) } }
    }

    /// The title of the front window and whether it has a close button, which document windows have and dialogs do not. Nil when no window is in front.
    @AccessibilityActor
    public func frontWindowFacts() throws -> FrontWindowFacts? {
        guard let window = try AXElement.application(pid: pid).focusedWindow else { return nil }
        return FrontWindowFacts(title: try window.title ?? "", hasCloseButton: try window.element("AXCloseButton") != nil)
    }
}

public struct FrontWindowFacts: Sendable, Equatable {
    public let title: String
    public let hasCloseButton: Bool

    public init(title: String, hasCloseButton: Bool) {
        self.title = title
        self.hasCloseButton = hasCloseButton
    }
}

/// When Flo Tools speaks after passing one of Pro Tools' own shortcuts on. The key is always sent first, as in the KM versions, and they checked afterwards whether it had reached the Edit or Mix window rather than being typed into a text field or taken by a dialog. Those checks came in two kinds, kept here as they were.
public enum AnnouncementGuard: Sendable, Equatable {
    case always
    /// Not in a dialog from the KM version's list of titles, and not with VoiceOver's keyboard cursor on a text field. Playlists, track views and the link settings.
    case outsideListedDialogsAndText
    /// Not in a window without a close button, and not with VoiceOver's keyboard cursor on a text field. Grid and Qwerty nudge steps.
    case outsideDialogsAndText
    /// Only with the Edit window in front. The keyboard focus keys.
    case inEditWindow

    /// Whether this guard reads VoiceOver's keyboard cursor.
    public var readsKeyboardCursor: Bool { self == .outsideListedDialogsAndText || self == .outsideDialogsAndText }

    /// The decision, from the front window (nil when there is none) and the text under VoiceOver's keyboard cursor.
    public func allows(_ window: FrontWindowFacts?, keyboardCursorText: String?) -> Bool {
        let inText = keyboardCursorText?.hasSuffix("edit text") ?? false
        switch self {
        case .always: return true
        case .outsideListedDialogsAndText: return !inText && !Self.isListedDialog(window?.title ?? "")
        case .outsideDialogsAndText: return !inText && window?.hasCloseButton == true
        case .inEditWindow: return window?.title.hasPrefix("Edit:") == true
        }
    }

    /// The KM version's title pattern for dialogs where the shortcuts do something else.
    static func isListedDialog(_ title: String) -> Bool {
        let prefixes = ["Dashboard", "Save", "Open", "Get Info", "Create Group", "Scroll To Track", "Name", "Metadata Inspector", "New Memory Location", "MIDI Event List", "Workspace", "Artist Chat"]
        return prefixes.contains { title.hasPrefix($0) } || title.hasSuffix("Bounce") || title.hasSuffix("Setup")
    }
}
