import FloSystem

/// What the front Pro Tools window and focus are, for commands that decide whether a passed-on shortcut reached the Edit or Mix window.
extension ProToolsApp {
    /// The title of the front window and whether it has a close button, which document windows have and dialogs do not. Nil when no window is in front.
    @AccessibilityActor
    public func frontWindowFacts() throws -> FrontWindowFacts? {
        guard let window = try AXElement.application(pid: pid).focusedWindow else { return nil }
        return FrontWindowFacts(title: try window.title ?? "", hasCloseButton: try window.element("AXCloseButton") != nil)
    }

    /// Whether the focused element has a text entry role. This is the focus, not proof that a key was typed: a counter being typed into does not take the focus.
    @AccessibilityActor
    public func hasTextEntryFocus() throws -> Bool {
        guard let role = try AXElement.application(pid: pid).focusedElement?.role else { return false }
        return Self.textEntryRoles.contains(role)
    }

    /// Checked live 2026-11-03: the clip list filter, the Scroll to Track dialog and a Mix window comments field have an AXTextArea focused while typing goes to them. Elsewhere the focus is an AXGroup (a track) or AXUnknown ("View", "Mixer scroller"), and the Main Counter clicked for typing leaves it on "View". AXTextField is the standard role of a text field.
    static let textEntryRoles: Set<String> = ["AXTextArea", "AXTextField"]
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
    /// Not in a dialog from the KM version's list of titles, and not typing in a text field. Playlists, track views and the link settings.
    case outsideListedDialogsAndText
    /// Not in a window without a close button, and not typing in a text field. Grid and Qwerty nudge steps.
    case outsideDialogsAndText
    /// Only with the Edit window in front. The keyboard focus keys.
    case inEditWindow

    /// Whether this guard needs `ProToolsApp.hasTextEntryFocus()`. Only these two read it, so a failed focus read cannot silence the others.
    public var readsTextFocus: Bool { self == .outsideListedDialogsAndText || self == .outsideDialogsAndText }

    /// The decision, from the front window (nil when there is none) and whether a text entry element has the focus. The KM versions told text entry by VoiceOver's keyboard cursor text ending in "edit text", which is VoiceOver's English wording; the focused element's role does not depend on VoiceOver's language.
    public func allows(_ window: FrontWindowFacts?, hasTextEntryFocus inText: Bool) -> Bool {
        switch self {
        case .always: return true
        case .outsideListedDialogsAndText: return !inText && !Self.isListedDialog(window?.title ?? "")
        case .outsideDialogsAndText: return !inText && window?.hasCloseButton == true
        case .inEditWindow: return window.map { ProToolsWindowKind(title: $0.title) } == .edit
        }
    }

    /// The KM version's title pattern for dialogs where the shortcuts do something else.
    static func isListedDialog(_ title: String) -> Bool {
        let prefixes = ["Dashboard", "Save", "Open", "Get Info", "Create Group", "Scroll To Track", "Name", "Metadata Inspector", "New Memory Location", "MIDI Event List", "Workspace", "Artist Chat"]
        return prefixes.contains { title.hasPrefix($0) } || title.hasSuffix("Bounce") || title.hasSuffix("Setup")
    }
}
