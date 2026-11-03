import FloSystem

/// A Pro Tools setting that is switched on and off: a button in one of the Edit window's toolbar clusters, or a menu bar item.
public enum ProToolsSetting: Sendable, Equatable {
    /// A button in the Edit window's group `cluster`, such as "MIDI Control Cluster". On when its value is "Selected".
    case editWindowButton(cluster: String, NameMatch)
    /// An item of the menu bar menu `menu`. On when it has a check mark.
    case menuItem(menu: String, NameMatch)

    /// How an element is picked by its name. Some names change with the setting, such as the Grid mode button ("Absolute Grid mode", "Relative Grid mode") or Track > "Set Record Tracks to Input Only".
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
}

/// The element that shows and switches a `ProToolsSetting`, found once per macro step. Everything here messages Pro Tools, so it runs on `AccessibilityActor`.
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
}

extension ProToolsApp {
    /// The control of `setting`, or `FloError.notFound` naming it, for example "the Metronome button" or "the Options menu item Loop Playback".
    @AccessibilityActor
    public func control(_ setting: ProToolsSetting) throws -> SettingControl {
        switch setting {
        case .editWindowButton(let cluster, let match):
            let edit = try window(titlePrefix: "Edit:", "the Edit window")
            let group = try edit.required("the \(cluster)") { try $0.group(cluster) }
            let button = try group.required("the \(match.text) button") { try $0.buttons.first { try match.matches($0.name) } }
            return SettingControl(setting, button)
        case .menuItem(let menu, let match):
            let app = AXElement.application(pid: pid)
            let bar = try app.required("the menu bar") { try $0.element("AXMenuBar") }
            let menuElement = try bar.required("the \(menu) menu") { try $0.child(role: "AXMenuBarItem", name: menu)?.children.first }
            let item = try menuElement.required("the \(menu) menu item \(match.text)") { try $0.children(role: "AXMenuItem").first { try match.matches($0.name) } }
            return SettingControl(setting, item)
        }
    }
}
