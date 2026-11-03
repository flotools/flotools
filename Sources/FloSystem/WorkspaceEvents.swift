import AppKit

/// Reports the workspace changes Flo Tools reacts to: apps launching and quitting, and VoiceOver turning on and off.
///
/// Owned by the main actor, and `onChange` is called on it. `start()` and `stop()` bound the observers; the app owns one instance.
@MainActor
public final class WorkspaceEvents {
    public enum Change: Sendable, Equatable {
        case launched(bundleID: String)
        case quit(bundleID: String)
        /// VoiceOver was turned on or off. From `NSWorkspace.isVoiceOverEnabled`, which follows the VoiceOver process like Keyboard Maestro's VoiceOver launch and quit triggers.
        case voiceOver(running: Bool)
    }

    public var onChange: ((Change) -> Void)?

    private var observers: [NSObjectProtocol] = []
    private var voiceOverObservation: NSKeyValueObservation?

    public init() {}

    /// Whether VoiceOver is on now.
    public static var isVoiceOverRunning: Bool { NSWorkspace.shared.isVoiceOverEnabled }

    public func start() {
        guard observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        for (name, change) in [(NSWorkspace.didLaunchApplicationNotification, Change.launched), (NSWorkspace.didTerminateApplicationNotification, Change.quit)] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                guard let bundleID = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier else { return }
                MainActor.assumeIsolated { self?.onChange?(change(bundleID)) }
            })
        }
        // KVO may report on any thread.
        voiceOverObservation = NSWorkspace.shared.observe(\.isVoiceOverEnabled, options: [.new]) { [weak self] _, change in
            guard let running = change.newValue else { return }
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.onChange?(.voiceOver(running: running)) } }
        }
    }

    public func stop() {
        observers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        observers = []
        voiceOverObservation?.invalidate()
        voiceOverObservation = nil
    }
}
