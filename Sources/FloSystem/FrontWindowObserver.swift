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
    /// Whether AXFocusedWindowChanged is registered on the observed app. Without it, switching between existing windows sends nothing, so the context must keep polling. Retried on every read.
    private var focusWatched = false
    /// Whether AXTitleChanged is registered on `watchedWindow`, or there is no window to watch. Retried on every read.
    private var titleWatched = true
    /// So a registration that keeps failing is logged once per app, not on every poll.
    private var registrationFailureLogged = false
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
        } else if !titleWatched {
            watchTitle(of: window)
        }
        if observer != nil, !focusWatched { watchFocus(pid: pid) }
        logRegistration()
        return FocusedWindow(title: try window?.title, number: windowNumber)
    }

    /// Whether notifications from app `pid` cover both a change of focused window and a change of its title. Only then is polling that app not needed.
    public func isObserving(pid: pid_t) -> Bool {
        observer != nil && observedPid == pid && focusWatched && titleWatched
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
        focusWatched = false
        titleWatched = true
        registrationFailureLogged = false
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
        var results: [String: AXError] = [:]
        for name in ["AXFocusedWindowChanged", "AXMainWindowChanged", "AXWindowCreated"] {
            results[name] = AXObserverAddNotification(created, app, name as CFString, refcon)
        }
        // With none registered, nothing would arrive; try attaching again on the next read. With some, the observer is kept, and `isObserving` stays false until AXFocusedWindowChanged is registered, so the context keeps polling.
        guard results.values.contains(.success) else {
            attachFailed(pid: pid, results.map { "\($0.key) \($0.value.rawValue)" }.sorted().joined(separator: ", "))
            return
        }
        focusWatched = results["AXFocusedWindowChanged"] == .success
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
        if let observer, let old = watchedWindow, titleWatched {
            old.removeNotification("AXTitleChanged", from: observer)
        }
        watchedWindow = window
        guard let observer, let window else {
            titleWatched = true
            return
        }
        titleWatched = window.addNotification("AXTitleChanged", to: observer, refcon: refcon) == .success
    }

    private func watchFocus(pid: pid_t) {
        guard let observer else { return }
        focusWatched = AXObserverAddNotification(observer, AXUIElementCreateApplication(pid), "AXFocusedWindowChanged" as CFString, refcon) == .success
    }

    /// Logs once when notifications do not cover every window change, and once when they do again.
    private func logRegistration() {
        guard observer != nil else { return }
        let covered = focusWatched && titleWatched
        if !covered, !registrationFailureLogged {
            registrationFailureLogged = true
            let missing = [focusWatched ? nil : "AXFocusedWindowChanged", titleWatched ? nil : "AXTitleChanged"].compactMap { $0 }
            Log.warning(.context, "pid \(observedPid): could not register \(missing.joined(separator: " and ")); polling instead, will retry")
        } else if covered, registrationFailureLogged {
            registrationFailureLogged = false
            Log.info(.context, "pid \(observedPid): window notifications registered after an earlier failure")
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
