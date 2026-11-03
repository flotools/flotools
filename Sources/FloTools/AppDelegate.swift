import AppKit
import FloMacros
import FloEngine
import FloSystem

/// Menu bar app with no Dock icon. The menu shows status and lets the user turn Flo Tools off.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let engine = FloMacros.makeEngine()
    private var statusItem: NSStatusItem?
    private var accessibilityTask: Task<Void, Never>?
    private var launchObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AXElement.setGlobalMessagingTimeout(1.0)
        applyPreferences()
        FloMacros.setStartState(Preferences.load(), in: engine)
        // A relaunch or crash while the user reproduces a problem keeps logging into the same file.
        Log.resumeRecording(header: DiagnosticHeader.text(engine: engine))
        Log.info(.app, "Flo Tools started")
        observeProToolsLaunch()
        engine.start()
        setUpStatusItem()

        if !Accessibility.isTrusted(prompt: true) {
            waitForAccessibility()
        }
        // Also makes macOS ask for permission to control VoiceOver on first launch.
        VoiceOver.say("Flo Tools started.")
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
        Log.info(.app, "Flo Tools quitting")
    }

    private func applyPreferences() {
        let preferences = Preferences.load()
        engine.doublePressTimeout = .milliseconds(preferences.timeout)
        FloMacros.apply(preferences, to: engine)
    }

    private func observeProToolsLaunch() {
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { notification in
            let bundleID = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated {
                FloMacros.applicationLaunched(bundleID: bundleID, in: self.engine)
            }
        }
    }

    private func waitForAccessibility() {
        accessibilityTask?.cancel()
        accessibilityTask = Task { @MainActor in
            while !Task.isCancelled, !Accessibility.isTrusted() {
                try? await Task.sleep(for: .seconds(2))
            }
            guard !Task.isCancelled else { return }
            Log.info(.app, "Accessibility permission granted")
            self.engine.refreshContext()
            VoiceOver.say("Flo Tools has accessibility access.")
        }
    }

    // MARK: Menu

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Flo"
        item.button?.setAccessibilityLabel("Flo Tools")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let enabled = NSMenuItem(title: "Flo Tools Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabled.state = engine.isEnabled ? .on : .off
        menu.addItem(enabled)
        menu.addItem(.separator())

        if Accessibility.isTrusted() {
            menu.addItem(disabled("Accessibility access granted"))
        } else {
            menu.addItem(NSMenuItem(title: "Grant Accessibility Access…", action: #selector(grantAccessibility), keyEquivalent: ""))
        }
        menu.addItem(disabled("\(engine.macros.count) macros"))
        menu.addItem(NSMenuItem(title: "Reload Preferences", action: #selector(reloadPreferences), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: Log.isRecording ? "Turn Off Log" : "Turn On Log", action: #selector(toggleLog), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Flo Tools", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items where item.action != nil { item.target = self }
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func toggleEnabled() {
        engine.isEnabled.toggle()
        VoiceOver.say(engine.isEnabled ? "Flo Tools enabled." : "Flo Tools disabled.")
    }

    @objc private func grantAccessibility() {
        Accessibility.isTrusted(prompt: true)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        waitForAccessibility()
    }

    @objc private func reloadPreferences() {
        applyPreferences()
    }

    /// Turning the log off shows the finished file in Finder, selected, so the user can send it as is.
    @objc private func toggleLog() {
        if Log.isRecording {
            Log.info(.app, "log turned off")
            guard let file = Log.stopRecording() else { return }
            NSWorkspace.shared.activateFileViewerSelecting([file])
        } else {
            do {
                try Log.startRecording(header: DiagnosticHeader.text(engine: engine))
                Log.info(.app, "log turned on")
                VoiceOver.say("Log turned on.")
            } catch {
                Log.error(.app, "could not start the log file: \(error)")
                VoiceOver.say("Could not start the log.")
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
