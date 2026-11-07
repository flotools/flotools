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

/// What an AX notification of the observed app said.
public enum FrontWindowEvent: Sendable {
    /// The focused window or its title may have changed.
    case windowMayHaveChanged
    /// The app opened a menu. Its window may also change by the time the menu closes.
    case menuOpened
    /// The app closed a menu.
    case menuClosed
    /// The selected text or insertion point of `element` changed. Pro Tools sends this when it opens a counter or other value field for typing, a field that does not become the app's focused element (checked live 2026-11-07).
    case selectedTextChanged(AXElementHandle)
}

/// Reads the focused window title of the front app and asks to be called again when it may have changed, through AX notifications. Also reports when the app opens and closes menus and when selected text changes.
///
/// Everything here messages the observed app, so it runs on `AccessibilityActor`. The notifications arrive on the main run loop, in the common modes so they also arrive while a menu is open; they only call `onChange`, which must not touch AX itself.
@AccessibilityActor
public final class FrontWindowObserver {
    /// What the C callback reaches through its refcon. Kept apart from the observer so `stop()` can keep it alive until the main run loop has finished a callback that was already running.
    private final class Callback: Sendable {
        /// Called on the main thread for each notification.
        let onChange: @Sendable (FrontWindowEvent) -> Void
        init(_ onChange: @escaping @Sendable (FrontWindowEvent) -> Void) { self.onChange = onChange }
    }

    private nonisolated let callback: Callback
    /// Set by `stop()`, so a read that was queued before it does not attach the observer again.
    private var stopped = false
    private var observer: AXObserver?
    /// The app the observer is attached to. Set only when attaching worked, so a failed attempt, for example before Accessibility access is granted, is tried again on the next read.
    private var observedPid: pid_t = 0
    /// The last app attaching failed for, so the failure is logged once and not on every retry.
    private var failedPid: pid_t = 0
    /// The window AXTitleChanged is registered on. Cleared when the observer is attached again, because the registration belonged to the old observer.
    private var watchedWindow: AXElement?
    /// The focused window the last read found, which `windowNumber` counts changes of. Kept apart from `watchedWindow`, so attaching the observer again does not count the same window as a new one.
    private var lastWindow: AXElement?
    /// Whether AXFocusedWindowChanged is registered on the observed app. Without it, switching between existing windows sends nothing, so the context must keep polling. Retried on every read.
    private var focusWatched = false
    /// Whether AXTitleChanged is registered on `watchedWindow`, or there is no window to watch. Retried on every read.
    private var titleWatched = true
    /// Whether AXMenuOpened and AXMenuClosed are registered on the observed app. Without AXMenuClosed, a plug-in chosen from a plug-in window's menu changes the title unseen (see `observe`), so the context must keep polling. Retried on every read.
    private var menuWatched = false
    /// Whether AXSelectedTextChanged is registered on the observed app. Not needed for the window title, so it does not affect `isObserving`. Retried on every read.
    private var selectedTextWatched = false
    /// So a registration that keeps failing is logged once per app, not on every poll.
    private var registrationFailureLogged = false
    /// Counts changes of the focused window, so two windows with the same title, such as two instances of one plug-in, still tell apart.
    private var windowNumber = 0

    /// Nonisolated so the main actor can create it; it only stores the callback.
    public nonisolated init(onChange: @escaping @Sendable (FrontWindowEvent) -> Void) {
        callback = Callback(onChange)
    }

    /// The focused window of app `pid`. Attaches the observer to that app first. Throws when the window cannot be read, for example while the app is busy.
    public func focusedWindow(pid: pid_t) throws -> FocusedWindow {
        guard !stopped else { throw CancellationError() }
        if pid != observedPid { observe(pid: pid) }
        let window = try AXElement.application(pid: pid).focusedWindow
        if !isSame(window, lastWindow) {
            lastWindow = window
            windowNumber += 1
        }
        if !isSame(window, watchedWindow) || !titleWatched { watchTitle(of: window) }
        if observer != nil, !focusWatched { focusWatched = watchApp(Self.focusChanged, pid: pid) }
        if observer != nil, !menuWatched { menuWatched = watchMenus(pid: pid) }
        if observer != nil, !selectedTextWatched { selectedTextWatched = watchApp(Self.selectedTextChanged, pid: pid) }
        logRegistration()
        return FocusedWindow(title: try window?.title, number: windowNumber)
    }

    /// Whether notifications from app `pid` cover every change of the focused window and its title: focus, title and menu. Only then is polling that app not needed.
    public func isObserving(pid: pid_t) -> Bool {
        observer != nil && observedPid == pid && focusWatched && titleWatched && menuWatched
    }

    /// Detaches from the observed app for good. Call before dropping the instance.
    public func stop() {
        stopped = true
        observe(pid: 0)
        lastWindow = nil
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
        menuWatched = false
        selectedTextWatched = false
        registrationFailureLogged = false
        guard pid > 0 else { return }
        var created: AXObserver?
        let status = AXObserverCreate(pid, { _, element, notification, refcon in
            guard let refcon else { return }
            let event: FrontWindowEvent = switch notification as String {
            case kAXMenuOpenedNotification: .menuOpened
            case kAXMenuClosedNotification: .menuClosed
            case kAXSelectedTextChangedNotification: .selectedTextChanged(AXElementHandle(element))
            default: .windowMayHaveChanged
            }
            Unmanaged<Callback>.fromOpaque(refcon).takeUnretainedValue().onChange(event)
        }, &created)
        guard status == .success, let created else {
            attachFailed(pid: pid, "AXObserverCreate \(status.rawValue)")
            return
        }
        let app = AXElement.application(pid: pid)
        var results: [String: AXError] = [:]
        for name in [Self.focusChanged, kAXMainWindowChangedNotification as String, kAXWindowCreatedNotification as String] {
            results[name] = app.addNotification(name, to: created, refcon: refcon)
        }
        // With none registered, nothing would arrive; try attaching again on the next read. With some, the observer is kept, and `isObserving` stays false until AXFocusedWindowChanged is registered, so the context keeps polling.
        guard results.values.contains(.success) else {
            attachFailed(pid: pid, results.map { "\($0.key) \($0.value.rawValue)" }.sorted().joined(separator: ", "))
            return
        }
        focusWatched = results[Self.focusChanged] == .success
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observer = created
        // Pro Tools changes a plug-in or AudioSuite window's title in place, without AXTitleChanged, when another plug-in is chosen from a menu; by AXMenuClosed the title is new (checked live 2026-11-03).
        menuWatched = watchMenus(pid: pid)
        // Watched on the whole app, unlike titles: it fires when a field opens for typing and as typing moves the insertion point, not as counters run (checked live 2026-11-07: 3 s of playback sent none).
        selectedTextWatched = watchApp(Self.selectedTextChanged, pid: pid)
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
            old.removeNotification(Self.titleChanged, from: observer)
        }
        watchedWindow = window
        guard let observer, let window else {
            titleWatched = true
            return
        }
        titleWatched = window.addNotification(Self.titleChanged, to: observer, refcon: refcon) == .success
    }

    /// Registers app notification `name`; returns whether it is registered now. One registered before, as when a retry follows a partial failure, counts.
    private func watchApp(_ name: String, pid: pid_t) -> Bool {
        guard let observer else { return false }
        let status = AXElement.application(pid: pid).addNotification(name, to: observer, refcon: refcon)
        return status == .success || status == .notificationAlreadyRegistered
    }

    /// Registers AXMenuOpened and AXMenuClosed; returns whether both are registered.
    private func watchMenus(pid: pid_t) -> Bool {
        [Self.menuOpened, Self.menuClosed].map { watchApp($0, pid: pid) }.allSatisfy { $0 }
    }

    /// Logs once when notifications do not cover every window change, and once when they do again.
    private func logRegistration() {
        guard observer != nil else { return }
        let covered = focusWatched && titleWatched && menuWatched && selectedTextWatched
        if !covered, !registrationFailureLogged {
            registrationFailureLogged = true
            let missing = [focusWatched ? nil : Self.focusChanged, titleWatched ? nil : Self.titleChanged, menuWatched ? nil : "\(Self.menuOpened) or \(Self.menuClosed)", selectedTextWatched ? nil : Self.selectedTextChanged].compactMap { $0 }
            Log.warning(.context, "pid \(observedPid): could not register \(missing.joined(separator: " and ")); polling window changes meanwhile, will retry")
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

    private static let focusChanged = kAXFocusedWindowChangedNotification as String
    private static let titleChanged = kAXTitleChangedNotification as String
    private static let menuOpened = kAXMenuOpenedNotification as String
    private static let menuClosed = kAXMenuClosedNotification as String
    private static let selectedTextChanged = kAXSelectedTextChangedNotification as String

    /// How AX notifications reach `callback`, which lives at least as long as the observer is attached.
    private var refcon: UnsafeMutableRawPointer { Unmanaged.passUnretained(callback).toOpaque() }
}
