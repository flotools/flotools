import AppKit
import FloProTools
import FloSystem

/// Which app is in front and the title of its focused window. Macro groups are active or not based on this.
public struct FrontContext: Equatable, Sendable, CustomStringConvertible {
    public var bundleID: String?
    public var windowTitle: String?
    /// Changes whenever another window of the app gets the focus, so a focus change between windows with the same title is a change of context. 0 when unknown.
    public var windowNumber: Int
    /// The front app's process, so a run accepted for one Pro Tools process does not start in another. 0 when unknown.
    public var processID: pid_t

    public init(bundleID: String? = nil, windowTitle: String? = nil, windowNumber: Int = 0, processID: pid_t = 0) {
        self.bundleID = bundleID
        self.windowTitle = windowTitle
        self.windowNumber = windowNumber
        self.processID = processID
    }

    /// The kind of the front window when Pro Tools is in front with a window, else nil. Derived from the title, so it cannot disagree with it.
    public var proToolsWindowKind: ProToolsWindowKind? {
        guard bundleID == ProToolsApp.bundleID, let windowTitle else { return nil }
        return ProToolsWindowKind(title: windowTitle)
    }

    /// For the log, for example `com.avid.ProTools "Mix: Session"`.
    public var description: String {
        "\(bundleID ?? "no app") \(windowTitle.map { "\"\($0)\"" } ?? "no window")"
    }
}

/// Bookkeeping for window title reads: at most one runs at a time, and its result is published only if no change was reported while it ran. Pure, so the ordering rules are tested without AX.
///
/// A change reported during a read means the result may be stale, so it is dropped and read again. The poll does not count as a change: when reads are slow, polls would otherwise drop every result.
struct WindowTitleReads {
    enum End: Equatable {
        /// The result is current.
        case publish
        /// The result may be stale; start read `id` instead.
        case readAgain(id: Int)
        /// The read was started before `reset()`, so nothing waits for it.
        case ignore
    }

    private var running: Int?
    private var changedDuringRead = false
    private var lastID = 0

    /// A notification, a front app change or start. Returns the ID of a read to start now, or nil when one is running.
    mutating func changeReported() -> Int? {
        if running != nil {
            changedDuringRead = true
            return nil
        }
        return startRead()
    }

    /// The slow poll. Starts a read only when none is running.
    mutating func pollTicked() -> Int? {
        running == nil ? startRead() : nil
    }

    mutating func readEnded(id: Int) -> End {
        guard id == running else { return .ignore }
        running = nil
        guard changedDuringRead else { return .publish }
        return .readAgain(id: startRead())
    }

    /// On stop: reads still running are ignored when they end.
    mutating func reset() {
        running = nil
        changedDuringRead = false
    }

    private mutating func startRead() -> Int {
        lastID += 1
        running = lastID
        changedDuringRead = false
        return lastID
    }
}

/// Watches the front app and its focused window title and reports changes.
///
/// The front app comes from NSWorkspace and is published at once. The window title needs AX calls, which can block while the app is busy, so it is read on `AccessibilityActor` and published when the read returns; meanwhile the title is unknown and window-specific keys pass through. The app owns one instance; `start()` and `stop()` bound the observers and the poll.
@MainActor
public final class ContextMonitor {
    public private(set) var current = FrontContext()
    public var onChange: ((FrontContext) -> Void)?

    private var windowObserver: FrontWindowObserver?
    private var reads = WindowTitleReads()
    private var activationObserver: NSObjectProtocol?
    private var poll: Task<Void, Never>?
    /// Whether the last window read found the observer attached to the front app. While it is, the poll reads no windows: notifications report every change (checked live 2026-11-02: Mix/Edit, dialog, floating window, app switch), and a poll read blocks `AccessibilityActor` for up to the messaging timeout when Pro Tools is busy.
    private var observing = false
    /// The app the last window read failed for, so a failure that the poll repeats every second, as while Pro Tools starts, is logged once, and its end once.
    private var failingReadPid: pid_t = 0

    public init() {}

    public func start() {
        guard poll == nil else { return }
        windowObserver = FrontWindowObserver { [weak self] in
            // AX notifications arrive on the main run loop.
            MainActor.assumeIsolated { self?.refresh() }
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        // AX notifications can be missing, for example before Accessibility access is granted, so also poll slowly.
        poll = Task { @MainActor [weak self] in
            while true {
                // Stop at once when cancelled, so no poll runs after `stop()`.
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                self?.pollTicked()
            }
        }
        refresh()
    }

    public func stop() {
        poll?.cancel()
        poll = nil
        observing = false
        failingReadPid = 0
        reads.reset()
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        activationObserver = nil
        if let observer = windowObserver {
            Task { @AccessibilityActor in observer.stop() }
        }
        windowObserver = nil
    }

    /// The cached context, refreshed first only when another app is now in front. For the hotkey callback, which must not wait: notifications and the poll keep window titles current.
    public func refreshIfFrontAppChanged() -> FrontContext {
        if frontAppChanged { refresh() }
        return current
    }

    /// Publishes a change of front app now and reads the window title in the background. A read already running is dropped and done again, because it may have started before this change.
    public func refresh() {
        guard poll != nil else { return }
        if frontAppChanged {
            let front = NSWorkspace.shared.frontmostApplication
            observing = false
            publish(FrontContext(bundleID: front?.bundleIdentifier, windowTitle: nil, processID: front?.processIdentifier ?? 0))
        }
        if let id = reads.changeReported() { readWindowTitle(id: id) }
    }

    private func pollTicked() {
        if frontAppChanged {
            Log.info(.context, "the poll found a front app change no notification reported")
            refresh()
        } else if !observing, let id = reads.pollTicked() {
            readWindowTitle(id: id)
        }
    }

    private var frontAppChanged: Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0 != current.processID
    }

    private func readWindowTitle(id: Int) {
        guard let observer = windowObserver else { return }
        let context = current
        Task { @MainActor in
            let (window, observing, failure): (FocusedWindow?, Bool, String?) = await Task { @AccessibilityActor in
                guard context.processID > 0 else { return (FocusedWindow(title: nil, number: 0), false, nil) }
                do {
                    let window = try observer.focusedWindow(pid: context.processID)
                    return (window, observer.isObserving(pid: context.processID), nil)
                } catch {
                    // Keep the last title. Reported as not observing, so the poll tries again even when no further notification comes.
                    return (nil, false, "\(error)")
                }
            }.value
            self.logReadOutcome(pid: context.processID, failure: failure)
            switch self.reads.readEnded(id: id) {
            case .publish:
                // Only for the app the read was for; a read for an app no longer in front says nothing about the new one.
                if context.processID == self.current.processID { self.observing = observing }
                if let window {
                    var updated = context
                    updated.windowTitle = window.title
                    updated.windowNumber = window.number
                    self.publish(updated)
                }
            case .readAgain(let next):
                self.readWindowTitle(id: next)
            case .ignore:
                break
            }
        }
    }

    private func logReadOutcome(pid: pid_t, failure: String?) {
        if let failure {
            guard failingReadPid != pid else { return }
            failingReadPid = pid
            Log.warning(.context, "could not read the focused window of pid \(pid), will retry: \(failure)")
        } else if failingReadPid == pid {
            failingReadPid = 0
            Log.info(.context, "read the focused window of pid \(pid) after an earlier failure")
        }
    }

    private func publish(_ context: FrontContext) {
        guard context != current else { return }
        current = context
        onChange?(context)
    }
}
