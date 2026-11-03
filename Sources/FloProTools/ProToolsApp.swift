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

    /// Whether this Pro Tools process is still running, for watches that outlive a macro run.
    public var isRunning: Bool {
        NSRunningApplication(processIdentifier: pid).map { !$0.isTerminated } ?? false
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
        MixWindow(try trackWindow(.mix))
    }

    @AccessibilityActor
    public func fadeDialog(_ kind: FadeDialog.Kind) throws -> FadeDialog {
        FadeDialog(try AXElement.application(pid: pid).required("the \(kind.rawValue) dialog") { app in try app.windows.first { try $0.title == kind.rawValue } })
    }

    /// Presses tab `number` (from 1) of the focused window, such as Preferences or I/O Setup, whose tabs are its radio buttons, and returns the tab's name. The JXA used `windows[0]`, the front window.
    @AccessibilityActor
    public func selectTab(_ number: Int) throws -> String {
        let window = try AXElement.application(pid: pid).required("the front window") { try $0.focusedWindow }
        let tab = try window.required("tab \(number)") { window in
            let tabs = try window.children(role: "AXRadioButton")
            return tabs.indices.contains(number - 1) ? tabs[number - 1] : nil
        }
        try tab.press()
        return try tab.name ?? ""
    }

    /// Whether any track is armed, hidden ones included. The Edit window's record status LED is named "Track Record Enabled" while a track is armed and "Record Enable status LED" otherwise (checked live 2026-11-02).
    @AccessibilityActor
    public func hasArmedTracks() throws -> Bool {
        let buttons = try window(titlePrefix: "Edit:", "the Edit window")
            .required("the Transport View Cluster") { try $0.group("Transport View Cluster") }
            .required("the Normal Transport Buttons") { try $0.group("Normal Transport Buttons") }
        return try buttons.button("Track Record Enabled") != nil
    }

    /// The two windows that show one group per track, named by their title prefix.
    public enum TrackWindow: String, Sendable {
        case mix = "Mix"
        case edit = "Edit"
    }

    /// The track whose name is under the VoiceOver cursor, as shown in `window`, like `mix.groups.byName(vo.voCursor.textUnderCursor())` in the JXA. Both windows name a track's group the same way, so the cursor can be in either. The one place the VoiceOver cursor is joined to a track.
    public func trackUnderVoiceOverCursor(in window: TrackWindow = .mix) async throws -> TrackStrip {
        let element = try await trackWindow(window)
        let name = try await VoiceOver.cursorText().required("the VoiceOver cursor")
        return try await TrackStrip(named: name, in: element, window: window)
    }

    /// The track named `name` in `window`, for watches that follow the VoiceOver cursor and read its text themselves.
    @AccessibilityActor
    public func track(named name: String, in window: TrackWindow = .mix) throws -> TrackStrip {
        try TrackStrip(named: name, in: trackWindow(window), window: window)
    }

    @AccessibilityActor
    private func trackWindow(_ window: TrackWindow) throws -> AXElement {
        try self.window(titlePrefix: window.rawValue + ":", "the \(window.rawValue) window")
    }

    /// The first window whose title starts with `titlePrefix`. `what` names it for the user, for example "the Mix window".
    @AccessibilityActor
    func window(titlePrefix: String, _ what: String) throws -> AXElement {
        try AXElement.application(pid: pid).required(what) { app in try app.windows.first { try $0.title?.hasPrefix(titlePrefix) == true } }
    }
}
