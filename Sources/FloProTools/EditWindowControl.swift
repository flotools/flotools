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

    /// Whether a key sent to Pro Tools now would be typed into a text field or go to a dialog rather than reach the Edit or Mix window. Text fields are what VoiceOver calls "edit text"; dialogs, unlike document windows, have no close button. The JXA asked VoiceOver's keyboard cursor and checked `AXCloseButton` of the front window.
    @AccessibilityActor
    public func keysGoToTextOrDialog() throws -> Bool {
        let app = AXElement.application(pid: pid)
        if let focused = try app.element("AXFocusedUIElement"), let role = try focused.role, ["AXTextField", "AXTextArea"].contains(role) { return true }
        guard let window = try app.focusedWindow else { return true }
        return try window.element("AXCloseButton") == nil
    }
}
