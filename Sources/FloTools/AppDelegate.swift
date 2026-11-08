import AppKit
import FloFeatures
import FloEngine
import FloSystem

/// Menu bar app with no Dock icon. The menu shows status and lets the user turn Flo Tools off.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    /// Read once here and passed down; the preferences panel is the only writer.
    private let preferences = PreferencesStore()
    /// Shared by the commands and `lifecycle`, which resets it when Pro Tools quits.
    private let session = SessionState()
    /// The app owns the input and context sources and hands them to the engine, which starts and stops them.
    private lazy var engine: Engine = FloFeatures.makeEngine(session: session, hotKeys: HotKeyCenter(), contextMonitor: ContextMonitor(), openPreferences: { [weak self] in
        self?.preferencesPanel.show()
    })
    private lazy var preferencesPanel: PreferencesPanel = PreferencesPanel(store: preferences, loginItem: loginItem) { [weak self] preferences in
        guard let self else { return }
        FloFeatures.apply(preferences, to: self.engine)
    }
    private lazy var lifecycle = Lifecycle(engine: engine, session: session, workspace: WorkspaceEvents()) { [weak self] in
        self?.preferences.current ?? Preferences()
    }
    private lazy var updater = Updater(preferences: preferences)
    private lazy var loginItem = LoginItem(preferences: preferences)
    /// Whether `main` continued the log file of the last launch, which then still needs this launch's header.
    private let resumedLog: Bool
    private var statusItem: NSStatusItem?
    private var accessibilityTask: Task<Void, Never>?
    private var logToggle: Task<Void, Never>?

    init(resumedLog: Bool) {
        self.resumedLog = resumedLog
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AXElement.setGlobalMessagingTimeout(1.0)
        engine.isEnabled = preferences.floToolsEnabled
        lifecycle.start()
        // After start, so the header shows the suspension and Inspector state that start set; the entries of start are already in the file.
        if resumedLog { Log.writeHeader(DiagnosticHeader.text(engine: engine, preferences: preferences.current, loginItem: loginItem)) }
        Log.info(.app, "Flo Tools started")
        installPlugInViewsOnFirstLaunch()
        loginItem.enableOnFirstLaunch()
        updater.start()
        engine.start()
        setUpStatusItem()

        if !Accessibility.isTrusted(prompt: true) {
            waitForAccessibility()
        }
        // Also makes macOS ask for permission to control VoiceOver on first launch.
        Task { await lifecycle.announceStartup() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        lifecycle.stop()
        engine.stop()
        Log.info(.app, "Flo Tools quitting")
    }

    /// A failed copy is logged and tried again on the next launch; a build without the views, such as `swift run`, never marks them installed.
    private func installPlugInViewsOnFirstLaunch() {
        guard !preferences.plugInViewsInstalled else { return }
        guard let shipped = Bundle.main.url(forResource: "Plug-In Views", withExtension: nil) else {
            Log.warning(.app, "the app has no Plug-In Views folder to install")
            return
        }
        do {
            let copied = try FloFeatures.installPlugInViews(from: shipped)
            preferences.plugInViewsInstalled = true
            Log.info(.app, "installed plug-in views: \(copied.isEmpty ? "none, the user had them all" : copied.joined(separator: ", "))")
        } catch {
            Log.error(.app, "could not install the plug-in views: \(error)")
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
            await VoiceOver.sayOrLog("Flo Tools has accessibility access.")
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

        let commandItems = engine.statusMenuCommands(in: engine.context)
        for command in commandItems {
            let item = NSMenuItem(title: command.name, action: #selector(runCommand), keyEquivalent: "")
            item.representedObject = command.id
            menu.addItem(item)
        }
        if !commandItems.isEmpty { menu.addItem(.separator()) }

        if Accessibility.isTrusted() {
            menu.addItem(disabled("Accessibility access granted"))
        } else {
            menu.addItem(NSMenuItem(title: "Grant Accessibility Access…", action: #selector(grantAccessibility), keyEquivalent: ""))
        }
        menu.addItem(disabled("\(engine.commands.count) commands"))
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: Log.isRecording ? "Turn Off Log" : "Turn On Log", action: #selector(toggleLog), keyEquivalent: ""))
        let updates = NSMenuItem(title: "Updates", action: nil, keyEquivalent: "")
        let updatesMenu = NSMenu(title: "Updates")
        // The updater dims the settings that depend on one that is off.
        updatesMenu.autoenablesItems = false
        updatesMenu.items = updater.menuItems()
        updates.submenu = updatesMenu
        menu.addItem(updates)
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
        preferences.floToolsEnabled = engine.isEnabled
        let text = engine.isEnabled ? "Flo Tools enabled." : "Flo Tools disabled."
        Task { await VoiceOver.sayOrLog(text) }
    }

    @objc private func runCommand(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? CommandID else { return }
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
    /// Ignores a second choice of the menu item while the first is still opening or closing the file.
    @objc private func toggleLog() {
        guard logToggle == nil else { return }
        logToggle = Task { @MainActor in
            defer { logToggle = nil }
            if Log.isRecording {
                Log.info(.app, "log turned off")
                guard let file = await Log.stopRecording() else { return }
                NSWorkspace.shared.activateFileViewerSelecting([file])
            } else {
                do {
                    try await Log.startRecording(header: DiagnosticHeader.text(engine: engine, preferences: preferences.current, loginItem: loginItem))
                    Log.info(.app, "log turned on")
                    await VoiceOver.sayOrLog("Log turned on.")
                } catch {
                    Log.error(.app, "could not start the log file: \(error)")
                    await VoiceOver.sayOrLog("Could not start the log.")
                }
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
