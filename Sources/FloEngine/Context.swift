import AppKit
import ApplicationServices
import FloSystem

/// Which app is in front and the title of its focused window. Macro groups are active or not based on this.
public struct FrontContext: Equatable, Sendable, CustomStringConvertible {
    public var bundleID: String?
    public var windowTitle: String?

    public init(bundleID: String? = nil, windowTitle: String? = nil) {
        self.bundleID = bundleID
        self.windowTitle = windowTitle
    }

    /// For the log, for example `com.avid.ProTools "Mix: Session"`.
    public var description: String {
        "\(bundleID ?? "no app") \(windowTitle.map { "\"\($0)\"" } ?? "no window")"
    }
}

/// Watches the front app and its focused window title and reports changes.
/// The app owns one instance; `start()` and `stop()` bound the observers and the poll.
@MainActor
public final class ContextMonitor {
    public private(set) var current = FrontContext()
    public var onChange: ((FrontContext) -> Void)?

    private var observer: AXObserver?
    private var observedPid: pid_t = 0
    private var observedWindow: AXElement?
    private var refreshScheduled = false
    private var activationObserver: NSObjectProtocol?
    private var poll: Task<Void, Never>?

    public init() {}

    public func start() {
        guard poll == nil else { return }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.refresh() }
        }
        // AX notifications can be missed, for example before Accessibility access is granted, so also poll slowly.
        poll = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.refresh()
            }
        }
        refresh()
    }

    public func stop() {
        poll?.cancel()
        poll = nil
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        activationObserver = nil
        observe(pid: 0)
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

    private func scheduleRefresh() {
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
        let status = AXObserverCreate(pid, { _, _, _, refcon in
            guard let refcon else { return }
            MainActor.assumeIsolated { Unmanaged<ContextMonitor>.fromOpaque(refcon).takeUnretainedValue().scheduleRefresh() }
        }, &created)
        guard status == .success, let created else { return }
        let app = AXUIElementCreateApplication(pid)
        for name in ["AXFocusedWindowChanged", "AXMainWindowChanged", "AXWindowCreated"] {
            AXObserverAddNotification(created, app, name as CFString, refcon)
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
            AXObserverAddNotification(observer, window.ref, "AXTitleChanged" as CFString, refcon)
        }
    }

    /// How AX notifications reach this instance. The app keeps the instance alive until `stop()` removes the observer.
    private var refcon: UnsafeMutableRawPointer { Unmanaged.passUnretained(self).toOpaque() }
}
