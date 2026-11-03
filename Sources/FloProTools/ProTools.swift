import AppKit
import FloSystem

/// Pro Tools as a running app and its windows. Process facts come from NSWorkspace and need no actor; window lookups message Pro Tools and run on `AccessibilityActor`.
public enum ProTools {
    public static let bundleID = "com.avid.ProTools"

    public static var runningApp: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
    }

    /// Pro Tools' version, or why it is not known. For the diagnostic log header.
    public static var version: String {
        guard let app = runningApp else { return "not running" }
        let version = app.bundleURL.flatMap { Bundle(url: $0)?.infoDictionary?["CFBundleShortVersionString"] as? String }
        return version ?? "running, version unknown"
    }

    public static var pid: pid_t? { runningApp?.processIdentifier }

    @AccessibilityActor
    public static func app() throws -> AXElement {
        AXElement.application(pid: try pid.required("Pro Tools"))
    }

    /// The first window whose title starts with `titlePrefix`. `what` names it for the user, for example "the Mix window".
    @AccessibilityActor
    public static func window(titlePrefix: String, _ what: String) throws -> AXElement {
        try app().required(what) { app in try app.windows.first { try $0.title?.hasPrefix(titlePrefix) == true } }
    }

    @AccessibilityActor
    public static func mixWindow() throws -> AXElement { try window(titlePrefix: "Mix:", "the Mix window") }

    /// Sends a keystroke to Pro Tools without going through global hotkeys.
    public static func keystroke(_ combo: KeyCombo) {
        guard let pid else { return }
        Keyboard.press(combo, pid: pid)
    }
}
