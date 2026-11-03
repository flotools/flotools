import AppKit
import FloMacros
import FloEngine
import FloSystem

/// Menu bar app with no Dock icon. The menu shows status and lets the user turn Flo Tools off.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    /// Read once here and passed down; the preferences panel is the only writer.
    private let preferences = PreferencesStore()
    /// The app owns the input and context sources and hands them to the engine, which starts and stops them.
    /// Shared by the macros and `lifecycle`, which resets it when Pro Tools quits.
    private let session = SessionState()
    private lazy var engine: MacroEngine = FloMacros.makeEngine(session: session, hotKeys: HotKeyCenter(), contextMonitor: ContextMonitor(), openPreferences: { [weak self] in
        self?.preferencesPanel.show()
    })
    private lazy var preferencesPanel: PreferencesPanel = PreferencesPanel(store: preferences) { [weak self] preferences in
        guard let self else { return }
        FloMacros.apply(preferences, to: self.engine)
    }
    private lazy var lifecycle = Lifecycle(engine: engine, session: session, workspace: WorkspaceEvents()) { [weak self] in
        self?.preferences.current ?? Preferences()
    }
    private var statusItem: NSStatusItem?
    private var accessibilityTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AXElement.setGlobalMessagingTimeout(1.0)
        lifecycle.start()
        // A relaunch or crash while the user reproduces a problem keeps logging into the same file.
        Log.resumeRecording(header: DiagnosticHeader.text(engine: engine, preferences: preferences.current))
        Log.info(.app, "Flo Tools started")
        engine.start()
        setUpStatusItem()

        if !Accessibility.isTrusted(prompt: true) {
            waitForAccessibility()
        }
        // Also makes macOS ask for permission to control VoiceOver on first launch.
        lifecycle.checkVoiceOver(saying: "Flo Tools started.")
    }

    func applicationWillTerminate(_ notification: Notification) {
        lifecycle.stop()
        engine.stop()
        Log.info(.app, "Flo Tools quitting")
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
            VoiceOver.sayOrLog("Flo Tools has accessibility access.")
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
        for suspension in engine.suspensions.sorted(by: { $0.reason < $1.reason }) {
            menu.addItem(disabled("Paused: \(suspension.reason)"))
        }
        menu.addItem(.separator())

        let macroItems = engine.statusMenuMacros(in: engine.context)
        for macro in macroItems {
            let item = NSMenuItem(title: macro.name, action: #selector(runMacro), keyEquivalent: "")
            item.representedObject = macro.id
            menu.addItem(item)
        }
        if !macroItems.isEmpty { menu.addItem(.separator()) }

        if Accessibility.isTrusted() {
            menu.addItem(disabled("Accessibility access granted"))
        } else {
            menu.addItem(NSMenuItem(title: "Grant Accessibility Access…", action: #selector(grantAccessibility), keyEquivalent: ""))
        }
        menu.addItem(disabled("\(engine.macros.count) macros"))
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(showPreferences), keyEquivalent: ","))
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
        VoiceOver.sayOrLog(engine.isEnabled ? "Flo Tools enabled." : "Flo Tools disabled.")
    }

    @objc private func runMacro(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? MacroID else { return }
        engine.run(id)
    }

    @objc private func grantAccessibility() {
        Accessibility.isTrusted(prompt: true)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        waitForAccessibility()
    }

    @objc private func showPreferences() {
        preferencesPanel.show()
    }

    /// Turning the log off shows the finished file in Finder, selected, so the user can send it as is.
    @objc private func toggleLog() {
        if Log.isRecording {
            Log.info(.app, "log turned off")
            guard let file = Log.stopRecording() else { return }
            NSWorkspace.shared.activateFileViewerSelecting([file])
        } else {
            do {
                try Log.startRecording(header: DiagnosticHeader.text(engine: engine, preferences: preferences.current))
                Log.info(.app, "log turned on")
                VoiceOver.sayOrLog("Log turned on.")
            } catch {
                Log.error(.app, "could not start the log file: \(error)")
                VoiceOver.sayOrLog("Could not start the log.")
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
