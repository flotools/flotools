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

    /// The name, or the part of it, that is matched.
    public var text: String {
        switch self {
        case .is(let text), .contains(let text): text
        }
    }
}

/// A control in the Edit window's toolbar, such as the Main Counter text field in "Counter Display Cluster" or the Pre-roll Amount in "Transport View Cluster" > "Transport Display".
public struct EditWindowControl: Sendable, Equatable {
    /// The Edit window's toolbar clusters, as Pro Tools 26.10 names them. The one place their names are written.
    public enum Cluster: String, Sendable {
        case counter = "Counter Display Cluster"
        case gridNudge = "Grid/Nudge Cluster"
        case transportView = "Transport View Cluster"
        case editMode = "Edit Mode Cluster"
        case midi = "MIDI Control Cluster"
        case cursorTool = "Cursor Tool Cluster"
    }

    public let cluster: Cluster
    /// Group names inside the cluster down to the group that holds the control, usually none.
    public let subgroups: [String]
    /// The control's AX role, for example "AXTextField".
    public let role: String
    public let name: NameMatch

    init(_ cluster: Cluster, _ subgroups: [String] = [], role: String, _ name: NameMatch) {
        self.cluster = cluster
        self.subgroups = subgroups
        self.role = role
        self.name = name
    }
}

extension AXElement {
    /// The first child with `role` whose name `match` picks. Lives here rather than beside `child(role:name:)` in FloSystem because `NameMatch` is Pro Tools vocabulary.
    func child(role: String, matching match: NameMatch) throws -> AXElement? {
        try children(role: role).first { try match.matches($0.name) }
    }
}

/// The Edit window's counters, time values and their selectors, as Pro Tools 26.10 names them.
extension EditWindowControl {
    private static func counter(_ name: String) -> EditWindowControl {
        EditWindowControl(.counter, role: "AXTextField", .is(name))
    }

    private static func transport(_ name: String) -> EditWindowControl {
        EditWindowControl(.transportView, ["Transport Display"], role: "AXTextField", .is(name))
    }

    public static let mainCounter = counter("Main Counter")
    public static let subCounter = counter("Sub Counter")
    public static let selectionStart = counter("Edit Selection Start")
    public static let selectionEnd = counter("Edit Selection End")
    public static let selectionLength = counter("Edit Selection Length")
    public static let notePitch = counter("MIDI Note Pitch")
    public static let attackVelocity = counter("MIDI Note Attack Velocity")
    public static let releaseVelocity = counter("MIDI Note Release Velocity")
    public static let mainCounterSelector = EditWindowControl(.counter, role: "AXButton", .is("Main Counter selector"))
    public static let subCounterSelector = EditWindowControl(.counter, role: "AXButton", .is("Sub Counter selector"))
    public static let preRoll = transport("Pre-roll Amount")
    public static let postRoll = transport("Post-roll Amount")
    public static let nudgeValue = EditWindowControl(.gridNudge, role: "AXTextField", .is("Nudge Custom Value"))
    public static let nudgeSelector = EditWindowControl(.gridNudge, role: "AXPopUpButton", .is("Nudge value"))
    public static let gridValue = EditWindowControl(.gridNudge, role: "AXPopUpButton", .is("Grid Value"))
    public static let tempo = EditWindowControl(.midi, role: "AXTextField", .is("Tempo value"))
}

extension ProToolsApp {
    /// The element of `control` in the Edit window, or `FloError.notFound` naming the missing step.
    @AccessibilityActor
    public func element(_ control: EditWindowControl) throws -> AXElement {
        let parent = try editGroup(control.cluster, subgroups: control.subgroups)
        return try parent.required("the \(control.name.text)") { try $0.child(role: control.role, matching: control.name) }
    }

    /// The Edit window's toolbar group `cluster`, then each of `subgroups` inside it, or `FloError.notFound` naming the missing step.
    @AccessibilityActor
    func editGroup(_ cluster: EditWindowControl.Cluster, subgroups: [String] = []) throws -> AXElement {
        var parent = try trackWindow(.edit)
        for group in [cluster.rawValue] + subgroups {
            parent = try parent.required("the \(group)") { try $0.group(group) }
        }
        return parent
    }

    /// The value `control` shows, empty when it has none.
    @AccessibilityActor
    public func value(of control: EditWindowControl) throws -> String {
        try element(control).value ?? ""
    }

    /// Clicks the field so the next typed digits replace its value, and returns the value it had.
    @AccessibilityActor
    public func openForTyping(_ control: EditWindowControl) throws -> String {
        let field = try element(control)
        let value = try field.value ?? ""
        try field.press()
        return value
    }
}
