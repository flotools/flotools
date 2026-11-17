import FloSystem

extension ProToolsApp {
    /// The setting control exists only on the Dashboard's New Session page. The
    /// window title can be the Pro Tools version, so identify it by its controls.
    @AccessibilityActor
    public func newSessionSetting(identifier: String) throws -> AXElement? {
        guard let window = try AXElement.application(pid: pid).focusedWindow else { return nil }
        let children = try window.children
        guard let newTab = try children.first(where: {
            try $0.string("AXIdentifier") == "QGuiApplication.DashboardWnd.tabBarNewTabButton"
        }), try newTab.value == "1",
        let configuration = try children.first(where: {
            try $0.string("AXIdentifier") == "QGuiApplication.DashboardWnd.sessionConfigContent"
        }) else { return nil }

        return try configuration.children.first {
            try $0.string("AXIdentifier") == "QGuiApplication.DashboardWnd.sessionConfigContent.\(identifier)"
        }
    }
}
