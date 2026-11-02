import AppKit

/// Shortcuts to Pro Tools' accessibility elements.
@MainActor
public enum ProTools {
    public static let bundleID = "com.avid.ProTools"

    public static var runningApp: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
    }

    public static var pid: pid_t? { runningApp?.processIdentifier }

    public static var app: AXElement? { pid.map { AXElement.application(pid: $0) } }

    public static var windows: [AXElement] { app?.windows ?? [] }

    public static func window(titlePrefix: String) -> AXElement? {
        windows.first { $0.title?.hasPrefix(titlePrefix) == true }
    }

    public static var mixWindow: AXElement? { window(titlePrefix: "Mix:") }
    public static var editWindow: AXElement? { window(titlePrefix: "Edit:") }

    /// Sends a keystroke to Pro Tools without going through global hotkeys.
    public static func keystroke(_ combo: KeyCombo) {
        guard let pid else { return }
        Keyboard.press(combo, pid: pid)
    }
}
