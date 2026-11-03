import AppKit
import FloSystem

/// Pro Tools as a running process: the one place that finds it and reaches its windows and keys. Process facts come from NSWorkspace and need no actor; window lookups message Pro Tools and run on `AccessibilityActor`.
public struct ProToolsApp: Sendable {
    public static let bundleID = "com.avid.ProTools"

    public let pid: pid_t

    /// The running Pro Tools, or `FloError.notFound("Pro Tools")`. Steps of one macro run use the same instance, so keys and clicks go to one process.
    public static func running() throws -> ProToolsApp {
        ProToolsApp(pid: try runningApplication.required("Pro Tools").processIdentifier)
    }

    /// Pro Tools' version, or why it is not known. For the diagnostic log header.
    public static var version: String {
        guard let app = runningApplication else { return "not running" }
        let version = app.bundleURL.flatMap { Bundle(url: $0)?.infoDictionary?["CFBundleShortVersionString"] as? String }
        return version ?? "running, version unknown"
    }

    private static var runningApplication: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
    }

    /// Sends a keystroke to Pro Tools without going through global hotkeys, and returns once it is posted.
    public func keystroke(_ combo: KeyCombo) async {
        await Keyboard.press(combo, pid: pid)
    }

    /// Suspends or resumes all mix groups with Pro Tools' Suspend All Groups command (Cmd+Shift+G), which switches between the two, and waits up to 1 s for the Group List to show it. Call it only when the groups are known to be active (to suspend) or suspended by this run (to resume).
    /// Throws `FloError.couldNot` when the Group List does not change. A cancelled wait returns early: the command has been sent, and a cancelled job still resumes the groups.
    public func setGroups(suspended: Bool, in mix: MixWindow) async throws {
        let goal = suspended ? "suspend the mix groups" : "resume the mix groups"
        let start = ContinuousClock.now
        await keystroke(KeyCombo("Cmd+Shift+G")!)
        // Suspended groups lose the "Active " prefix in the Group List (checked live 2026-11-02).
        while try await mix.hasActiveGroups() == suspended {
            guard ContinuousClock.now - start < .seconds(1) else { throw FloError.couldNot(goal) }
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
        }
        Log.info(.accessibility, "\(goal): Group List changed (\(Log.elapsed(since: start)))")
    }

    @AccessibilityActor
    public func mixWindow() throws -> MixWindow {
        MixWindow(try window(titlePrefix: "Mix:", "the Mix window"))
    }

    /// The Mix window track strip whose name is under the VoiceOver cursor, like `mix.groups.byName(vo.voCursor.textUnderCursor())` in the JXA. The one place the VoiceOver cursor is joined to a strip.
    public func trackUnderVoiceOverCursor() async throws -> TrackStrip {
        let mix = try await mixWindow()
        let name = try await VoiceOver.cursorText().required("the VoiceOver cursor")
        return try await mix.strip(named: name)
    }

    /// The first window whose title starts with `titlePrefix`. `what` names it for the user, for example "the Mix window".
    @AccessibilityActor
    private func window(titlePrefix: String, _ what: String) throws -> AXElement {
        try AXElement.application(pid: pid).required(what) { app in try app.windows.first { try $0.title?.hasPrefix(titlePrefix) == true } }
    }
}
