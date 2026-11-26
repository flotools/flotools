import FloSystem

extension ProToolsApp {
    /// The setting control exists only on the Dashboard's New Session page. The window title can be the Pro Tools version, so identify it by its controls.
    /// Nil is normal in other windows, whose keys the Dashboard commands also take, so each step that finds nothing is logged at debug level with every attribute of the element where it stopped and of its children: on macOS 15 the setting was not spoken unless the VoiceOver cursor had been on it, and the log shows which step fails.
    @AccessibilityActor
    public func newSessionSetting(identifier: String) throws -> AXElement? {
        guard let window = try AXElement.application(pid: pid).focusedWindow else {
            Log.debug(.accessibility, "Dashboard: no focused window")
            return nil
        }
        let children = try window.children
        guard let newTab = try children.first(where: {
            try $0.string("AXIdentifier") == "QGuiApplication.DashboardWnd.tabBarNewTabButton"
        }) else {
            Log.debug(.accessibility, "Dashboard: no New tab button in the focused window:\n\(window.attributeDump())")
            return nil
        }
        guard try newTab.value == "1" else {
            Log.debug(.accessibility, "Dashboard: New tab not selected:\n\(newTab.attributeDump())")
            return nil
        }
        guard let configuration = try children.first(where: {
            try $0.string("AXIdentifier") == "QGuiApplication.DashboardWnd.sessionConfigContent"
        }) else {
            Log.debug(.accessibility, "Dashboard: no session settings in the focused window:\n\(window.attributeDump())")
            return nil
        }
        guard let control = try configuration.children.first(where: {
            try $0.string("AXIdentifier") == "QGuiApplication.DashboardWnd.sessionConfigContent.\(identifier)"
        }) else {
            Log.debug(.accessibility, "Dashboard: no \(identifier) in the session settings:\n\(configuration.attributeDump())")
            return nil
        }
        return control
    }
}
