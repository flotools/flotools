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
    /// The app the observer is attached to. Set only when attaching worked, so a failed attempt, for example before Accessibility access is granted, is tried again on the next refresh.
    private var observedPid: pid_t = 0
    /// The last app attaching failed for, so the failure is logged once and not on every retry.
    private var failedPid: pid_t = 0
    private var frontPid: pid_t = 0
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
            while true {
                // Stop at once when cancelled, so no refresh runs after `stop()` and attaches a new observer.
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
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
        failedPid = 0
    }

    /// The cached context, refreshed first only when another app is now in front. For the hotkey callback, which must not wait for a busy Pro Tools: notifications and the poll keep window titles current, and the front app check needs no Accessibility call.
    public func refreshIfFrontAppChanged() -> FrontContext {
        let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
        return pid == frontPid ? current : refresh()
    }

    /// Reads the current context now and reports it if it changed.
    @discardableResult
    public func refresh() -> FrontContext {
        let front = NSWorkspace.shared.frontmostApplication
        let pid = front?.processIdentifier ?? 0
        frontPid = pid
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
            guard self.poll != nil else { return }  // stopped meanwhile
            self.refresh()
        }
    }

    private func observe(pid: pid_t) {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        observedWindow = nil
        observedPid = 0
        guard pid > 0 else { return }
        var created: AXObserver?
        let status = AXObserverCreate(pid, { _, _, _, refcon in
            guard let refcon else { return }
            MainActor.assumeIsolated { Unmanaged<ContextMonitor>.fromOpaque(refcon).takeUnretainedValue().scheduleRefresh() }
        }, &created)
        guard status == .success, let created else {
            attachFailed(pid: pid, "AXObserverCreate \(status.rawValue)")
            return
        }
        let app = AXUIElementCreateApplication(pid)
        var failures: [String] = []
        for name in ["AXFocusedWindowChanged", "AXMainWindowChanged", "AXWindowCreated"] {
            let result = AXObserverAddNotification(created, app, name as CFString, refcon)
            if result != .success { failures.append("\(name) \(result.rawValue)") }
        }
        // Some apps do not send every notification; one is enough to follow window changes.
        guard failures.count < 3 else {
            attachFailed(pid: pid, failures.joined(separator: ", "))
            return
        }
        // Common modes, so notifications still arrive while a menu is open.
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observer = created
        observedPid = pid
        if failedPid == pid { Log.info(.context, "observing pid \(pid) after an earlier failure") }
        failedPid = 0
    }

    private func attachFailed(pid: pid_t, _ reason: String) {
        guard failedPid != pid else { return }
        failedPid = pid
        Log.warning(.context, "could not observe pid \(pid), will retry: \(reason)")
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
