import ApplicationServices
import Foundation

/// The focused window as the observer saw it.
public struct FocusedWindow: Sendable, Equatable {
    /// Nil when the app has no focused window.
    public let title: String?
    /// Changes whenever another window gets the focus, also between windows with the same title.
    public let number: Int

    public init(title: String?, number: Int) {
        self.title = title
        self.number = number
    }
}

/// Reads the focused window title of the front app and asks to be called again when it may have changed, through AX notifications.
///
/// Everything here messages the observed app, so it runs on `AccessibilityActor`. The notifications arrive on the main run loop, in the common modes so they also arrive while a menu is open; they only call `onChange`, which must not touch AX itself.
@AccessibilityActor
public final class FrontWindowObserver {
    /// What the C callback reaches through its refcon. Kept apart from the observer so `stop()` can keep it alive until the main run loop has finished a callback that was already running.
    private final class Callback: Sendable {
        /// Called on the main thread when the app's focused window or its title may have changed.
        let onChange: @Sendable () -> Void
        init(_ onChange: @escaping @Sendable () -> Void) { self.onChange = onChange }
    }

    private nonisolated let callback: Callback
    /// Set by `stop()`, so a read that was queued before it does not attach the observer again.
    private var stopped = false
    private var observer: AXObserver?
    /// The app the observer is attached to. Set only when attaching worked, so a failed attempt, for example before Accessibility access is granted, is tried again on the next read.
    private var observedPid: pid_t = 0
    /// The last app attaching failed for, so the failure is logged once and not on every retry.
    private var failedPid: pid_t = 0
    private var watchedWindow: AXElement?
    /// Counts changes of the focused window, so two windows with the same title, such as two instances of one plug-in, still tell apart.
    private var windowNumber = 0

    /// Nonisolated so the main actor can create it; it only stores the callback.
    public nonisolated init(onChange: @escaping @Sendable () -> Void) {
        callback = Callback(onChange)
    }

    /// The focused window of app `pid`. Attaches the observer to that app first. Throws when the window cannot be read, for example while the app is busy.
    public func focusedWindow(pid: pid_t) throws -> FocusedWindow {
        guard !stopped else { throw CancellationError() }
        if pid != observedPid { observe(pid: pid) }
        let window = try AXElement.application(pid: pid).focusedWindow
        if !isSame(window, watchedWindow) {
            watchTitle(of: window)
            windowNumber += 1
        }
        return FocusedWindow(title: try window?.title, number: windowNumber)
    }

    /// Whether notifications from app `pid` arrive. While they do, polling that app is not needed.
    public func isObserving(pid: pid_t) -> Bool {
        observer != nil && observedPid == pid
    }

    /// Detaches from the observed app for good. Call before dropping the instance.
    public func stop() {
        stopped = true
        observe(pid: 0)
        failedPid = 0
        // Callbacks run on the main thread, so once this block runs there is none in progress, and the source is removed, so none follows.
        let callback = callback
        DispatchQueue.main.async { withExtendedLifetime(callback) {} }
    }

    private func observe(pid: pid_t) {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        watchedWindow = nil
        observedPid = 0
        guard pid > 0 else { return }
        var created: AXObserver?
        let status = AXObserverCreate(pid, { _, _, _, refcon in
            guard let refcon else { return }
            Unmanaged<Callback>.fromOpaque(refcon).takeUnretainedValue().onChange()
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
        // Pro Tools changes a plug-in or AudioSuite window's title in place, without AXTitleChanged, when another plug-in is chosen from a menu; by AXMenuClosed the title is new (checked live 2026-11-03). Optional: the window notifications above still follow everything else.
        let menuResult = AXObserverAddNotification(created, app, "AXMenuClosed" as CFString, refcon)
        if menuResult != .success { Log.debug(.context, "watch AXMenuClosed failed: AXError \(menuResult.rawValue)") }
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
    private func watchTitle(of window: AXElement?) {
        if let observer, let old = watchedWindow {
            old.removeNotification("AXTitleChanged", from: observer)
        }
        watchedWindow = window
        if let observer, let window {
            window.addNotification("AXTitleChanged", to: observer, refcon: refcon)
        }
    }

    private func isSame(_ a: AXElement?, _ b: AXElement?) -> Bool {
        switch (a, b) {
        case (nil, nil): true
        case let (a?, b?): a.isSame(as: b)
        default: false
        }
    }

    /// How AX notifications reach `callback`, which lives at least as long as the observer is attached.
    private var refcon: UnsafeMutableRawPointer { Unmanaged.passUnretained(callback).toOpaque() }
}
