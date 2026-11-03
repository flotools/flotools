import FloSystem

/// A Pro Tools setting that is switched on and off: a button in one of the Edit window's toolbar clusters, or a menu bar item.
public enum ProToolsSetting: Sendable, Equatable {
    /// A button in one of the Edit window's toolbar clusters, such as the MIDI Control Cluster. On when its value is "Selected".
    case editWindowButton(EditWindowControl.Cluster, NameMatch)
    /// An item of the menu bar menu `menu`. On when it has a check mark.
    case menuItem(menu: String, NameMatch)
}

/// The element that shows and switches a `ProToolsSetting`, found once per command step. Everything here messages Pro Tools, so it runs on `AccessibilityActor`.
@AccessibilityActor
public struct SettingControl {
    public let setting: ProToolsSetting
    private let element: AXElement

    init(_ setting: ProToolsSetting, _ element: AXElement) {
        self.setting = setting
        self.element = element
    }

    public var isOn: Bool {
        get throws {
            switch setting {
            case .editWindowButton: try element.value == "Selected"
            case .menuItem: try element.menuItemMark != nil
            }
        }
    }

    /// The element's current name, for settings whose name tells their state.
    public var name: String { get throws { try element.name ?? "" } }

    /// False when Pro Tools dims the item, for example a menu command that does not apply now.
    public var isEnabled: Bool { get throws { try element.isEnabled } }

    /// Clicks the button or chooses the menu item, without opening the menu.
    public func press() throws { try element.press() }

    /// The grid kind that the Grid mode button names, for example "Absolute " from "Absolute Grid mode". The label is removed as the JXA did, which keeps the space before it.
    public nonisolated static func gridKind(buttonName: String) -> String {
        buttonName.replacingFirst("Grid mode", with: "")
    }

    /// How record-armed tracks monitor their input: the two modes of Track > Set Record Tracks to.
    public enum InputMonitorMode: Sendable, Equatable {
        case autoInput, inputOnly
    }

    /// The current mode, from the name of the Set Record Tracks to item, which offers the other mode: "Set Record Tracks to Auto Input" means Input Only is on.
    public nonisolated static func inputMonitorMode(itemName: String) -> InputMonitorMode {
        itemName.contains("Auto Input") ? .inputOnly : .autoInput
    }
}

extension ProToolsApp {
    /// The control of `setting`, or `FloError.notFound` naming it, for example "the Metronome button" or "the Options menu item Loop Playback".
    @AccessibilityActor
    public func control(_ setting: ProToolsSetting) throws -> SettingControl {
        switch setting {
        case .editWindowButton(let cluster, let match):
            return SettingControl(setting, try element(EditWindowControl(cluster, role: "AXButton", match)))
        case .menuItem(let menu, let match):
            return SettingControl(setting, try menuItem(menu, match))
        }
    }

    /// The name of Edit > Undo, which names the last undoable action, for example "Undo Drag from Bin". Read without opening the menu.
    @AccessibilityActor
    public func undoItemName() throws -> String {
        try menuItem("Edit", .contains("Undo")).name ?? ""
    }

    /// The first item of menu bar menu `menu` that `match` picks, or `FloError.notFound` naming it.
    @AccessibilityActor
    private func menuItem(_ menu: String, _ match: NameMatch) throws -> AXElement {
        let app = AXElement.application(pid: pid)
        let bar = try app.required("the menu bar") { try $0.element("AXMenuBar") }
        let menuElement = try bar.required("the \(menu) menu") { try $0.child(role: "AXMenuBarItem", name: menu)?.children.first }
        return try menuElement.required("the \(menu) menu item \(match.text)") { try $0.child(role: "AXMenuItem", matching: match) }
    }
}
