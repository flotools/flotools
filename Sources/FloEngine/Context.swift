import AppKit
import FloSystem

/// Which app is in front and the title of its focused window. Macro groups are active or not based on this.
public struct FrontContext: Equatable, Sendable, CustomStringConvertible {
    public var bundleID: String?
    public var windowTitle: String?
    /// The front app's process, so a run accepted for one Pro Tools process does not start in another. 0 when unknown.
    public var processID: pid_t

    public init(bundleID: String? = nil, windowTitle: String? = nil, processID: pid_t = 0) {
        self.bundleID = bundleID
        self.windowTitle = windowTitle
        self.processID = processID
    }

    /// For the log, for example `com.avid.ProTools "Mix: Session"`.
    public var description: String {
        "\(bundleID ?? "no app") \(windowTitle.map { "\"\($0)\"" } ?? "no window")"
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
    /// Changes on start, stop and front app change, so a window read that started before is not published after.
    private var generation = 0
    private var reading = false
    private var readAgain = false
    private var activationObserver: NSObjectProtocol?
    private var poll: Task<Void, Never>?

    public init() {}

    public func start() {
        guard poll == nil else { return }
        generation += 1
        windowObserver = FrontWindowObserver { [weak self] in
            // AX notifications arrive on the main run loop.
            MainActor.assumeIsolated { self?.refresh() }
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        // AX notifications can be missed, for example before Accessibility access is granted, so also poll slowly.
        poll = Task { @MainActor [weak self] in
            while true {
                // Stop at once when cancelled, so no refresh runs after `stop()`.
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                self?.refresh()
            }
        }
        refresh()
    }

    public func stop() {
        poll?.cancel()
        poll = nil
        generation += 1
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        activationObserver = nil
        if let observer = windowObserver {
            Task { @AccessibilityActor in observer.stop() }
        }
        windowObserver = nil
    }

    /// The cached context, refreshed first only when another app is now in front. For the hotkey callback, which must not wait: notifications and the poll keep window titles current.
    public func refreshIfFrontAppChanged() -> FrontContext {
        if NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0 != current.processID { refresh() }
        return current
    }

    /// Publishes a change of front app now and reads the window title in the background. Overlapping requests are merged into one more read.
    public func refresh() {
        guard poll != nil else { return }
        let front = NSWorkspace.shared.frontmostApplication
        let pid = front?.processIdentifier ?? 0
        if pid != current.processID {
            generation += 1
            publish(FrontContext(bundleID: front?.bundleIdentifier, windowTitle: nil, processID: pid))
        }
        if reading {
            readAgain = true
        } else {
            readWindowTitle()
        }
    }

    private func readWindowTitle() {
        guard let observer = windowObserver else { return }
        reading = true
        readAgain = false
        let context = current
        let generation = generation
        Task { @MainActor in
            let title: String?? = await Task { @AccessibilityActor in
                guard context.processID > 0 else { return .some(nil) }
                do {
                    return .some(try observer.focusedWindowTitle(pid: context.processID))
                } catch {
                    // Keep the last title; the poll or the next notification tries again.
                    Log.debug(.context, "window read failed: \(error)")
                    return .none
                }
            }.value
            self.reading = false
            if let title, generation == self.generation {
                var updated = context
                updated.windowTitle = title
                self.publish(updated)
            }
            if self.readAgain { self.refresh() }
        }
    }

    private func publish(_ context: FrontContext) {
        guard context != current else { return }
        current = context
        onChange?(context)
    }
}
