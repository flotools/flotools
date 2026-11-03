import AppKit
import ApplicationServices
import FloSystem

/// Which app is in front and the title of its focused window. Macro groups are active or not based on this.
public struct FrontContext: Equatable, Sendable {
    public var bundleID: String?
    public var windowTitle: String?

    public init(bundleID: String? = nil, windowTitle: String? = nil) {
        self.bundleID = bundleID
        self.windowTitle = windowTitle
    }
}

/// Watches the front app and its focused window title and reports changes.
@MainActor
public final class ContextMonitor {
    public static let shared = ContextMonitor()

    public private(set) var current = FrontContext()
    public var onChange: ((FrontContext) -> Void)?

    private var observer: AXObserver?
    private var observedPid: pid_t = 0
    private var observedWindow: AXElement?
    private var refreshScheduled = false
    private var started = false

    public func start() {
        guard !started else { return }
        started = true
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { _ = ContextMonitor.shared.refresh() }
        }
        // AX notifications can be missed, for example before Accessibility access is granted, so also poll slowly.
        Task { @MainActor in
            while true {
                try? await Task.sleep(for: .seconds(1))
                self.refresh()
            }
        }
        refresh()
    }

    /// Reads the current context now and reports it if it changed.
    @discardableResult
    public func refresh() -> FrontContext {
        let front = NSWorkspace.shared.frontmostApplication
        let pid = front?.processIdentifier ?? 0
        if pid != observedPid { observe(pid: pid) }
        let window = pid > 0 ? AXElement.application(pid: pid).focusedWindow : nil
        if window != observedWindow { observeTitle(of: window) }
        let context = FrontContext(bundleID: front?.bundleIdentifier, windowTitle: window?.title)
        if context != current {
            current = context
            onChange?(context)
        }
        return context
    }

    fileprivate func scheduleRefresh() {
        guard !refreshScheduled else { return }
        refreshScheduled = true
        Task { @MainActor in
            self.refreshScheduled = false
            self.refresh()
        }
    }

    private func observe(pid: pid_t) {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil
        observedWindow = nil
        observedPid = pid
        guard pid > 0 else { return }
        var created: AXObserver?
        let status = AXObserverCreate(pid, { _, _, _, _ in
            MainActor.assumeIsolated { ContextMonitor.shared.scheduleRefresh() }
        }, &created)
        guard status == .success, let created else { return }
        let app = AXUIElementCreateApplication(pid)
        for name in ["AXFocusedWindowChanged", "AXMainWindowChanged", "AXWindowCreated"] {
            AXObserverAddNotification(created, app, name as CFString, nil)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .defaultMode)
        observer = created
    }

    /// Title changes are watched on the focused window only, because watching the whole app would also report every changing counter.
    private func observeTitle(of window: AXElement?) {
        if let observer, let old = observedWindow {
            AXObserverRemoveNotification(observer, old.ref, "AXTitleChanged" as CFString)
        }
        observedWindow = window
        if let observer, let window {
            AXObserverAddNotification(observer, window.ref, "AXTitleChanged" as CFString, nil)
        }
    }
}
