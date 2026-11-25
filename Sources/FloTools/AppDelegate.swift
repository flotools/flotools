import AppKit
import FloFeatures
import FloEngine
import FloSystem

/// Menu bar app with no Dock icon. The menu shows status, runs the commands offered there, counts and lists the active commands, and lets the user turn Flo Tools off.
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
    private lazy var activeCommandsWindow = ActiveCommandsWindow()
    private lazy var updater = Updater(preferences: preferences)
    private lazy var loginItem = LoginItem(preferences: preferences)
    /// Whether `main` continued the log file of the last launch, which then still needs this launch's header.
    private let resumedLog: Bool
    private var statusItem: NSStatusItem?
    /// The front app and window whose commands the menu counts and lists. Set each time the menu opens, except while Flo Tools itself is in front, for example with the active commands window open: its commands are those of the window the user came from.
    private var listedContext = FrontContext()
    private var accessibilityTask: Task<Void, Never>?
    private var logToggle: Task<Void, Never>?

    init(resumedLog: Bool) {
        self.resumedLog = resumedLog
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AXElement.setGlobalMessagingTimeout(1.0)
        engine.isEnabled = preferences.floToolsEnabled
        lifecycle.start()
        // After start, so the header shows the suspension that start set; the entries of start are already in the file.
        if resumedLog { Log.writeHeader(DiagnosticHeader.text(engine: engine, preferences: preferences.current, loginItem: loginItem)) }
        Log.info(.app, "Flo Tools started")
        installPlugInViewsOnFirstLaunch()
        loginItem.enableOnFirstLaunch()
        updater.start()
        engine.start()
        setUpStatusItem()

        Task { await askForPermissionsAndAnnounce() }
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

        menu.addItem(permissionsItem())
        if engine.context.processID != ProcessInfo.processInfo.processIdentifier { listedContext = engine.context }
        let active = engine.activeCommands(in: listedContext).count
        menu.addItem(NSMenuItem(title: "\(active)/\(engine.commands.count) active commands", action: #selector(showActiveCommands), keyEquivalent: ""))
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

        target(menu)
    }

    /// Sends the actions of `menu`'s items to this delegate.
    private func target(_ menu: NSMenu) {
        for item in menu.items where item.action != nil { item.target = self }
    }

    private func permissionsItem() -> NSMenuItem {
        let submenu = NSMenu(title: "Permissions")
        if Accessibility.isTrusted() {
            submenu.addItem(disabled("Accessibility access granted"))
        } else {
            submenu.addItem(NSMenuItem(title: "Grant Accessibility Access…", action: #selector(grantAccessibility), keyEquivalent: ""))
        }
        if VoiceOver.automationPermission() == .granted {
            submenu.addItem(disabled("VoiceOver control allowed"))
        } else {
            submenu.addItem(NSMenuItem(title: "Allow Control of VoiceOver…", action: #selector(allowVoiceOverControl), keyEquivalent: ""))
        }
        submenu.addItem(.separator())
        submenu.addItem(NSMenuItem(title: "Reset All Permissions…", action: #selector(resetAllPermissions), keyEquivalent: ""))
        target(submenu)
        let item = NSMenuItem(title: "Permissions", action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
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

    /// The menu offers this only while not trusted, so any entry Flo Tools has is off or stale (from an earlier signature); resetting it makes macOS add a fresh one that the user turns on.
    @objc private func grantAccessibility() {
        Task {
            await resetOwnAnswer(.accessibility)
            Accessibility.isTrusted(prompt: true)
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            waitForAccessibility()
        }
    }

    /// macOS shows its consent dialog only if the user has not answered yet, so a Don't Allow is reset first.
    @objc private func allowVoiceOverControl() {
        Task {
            if VoiceOver.automationPermission() == .denied { await resetOwnAnswer(.appleEvents) }
            let result = await VoiceOver.requestAutomationPermission()
            Log.info(.app, "VoiceOver automation permission after asking: \(result)")
            await VoiceOver.sayOrLog("VoiceOver control \(result).")
        }
    }

    /// One dialog at a time: VoiceOver control first, because its dialog waits for the answer, then Accessibility, whose prompt sends the user to System Settings. Speech works without a recorded VoiceOver answer but does not make macOS ask for one (seen 2026-11-07), so it is asked for here. A recorded Don't Allow is kept: macOS returns it without a dialog, and only the menu item resets it.
    /// The startup announcement waits for the VoiceOver answer. After a Don't Allow, VoiceOver speech still mostly works (seen 2026-11-07), so it cannot be relied on to report the refusal; the system voice says it instead of the announcement.
    private func askForPermissionsAndAnnounce() async {
        var voiceOverControl = AutomationPermission.granted
        if VoiceOver.automationPermission() != .granted {
            voiceOverControl = await VoiceOver.requestAutomationPermission()
            Log.info(.app, "VoiceOver automation permission after asking at launch: \(voiceOverControl)")
        }
        if voiceOverControl == .denied {
            SystemSpeech.say("Flo Tools is not allowed to control VoiceOver. Choose Allow Control of VoiceOver in the Permissions menu of Flo Tools.")
        } else {
            await lifecycle.announceStartup()
        }
        if !Accessibility.isTrusted(prompt: true) {
            waitForAccessibility()
        }
    }

    /// A failed reset is logged and the request goes ahead: macOS then shows the old answer, which the user can still change in System Settings.
    private func resetOwnAnswer(_ permission: PrivacyPermission) async {
        do {
            try await Task.detached { try permission.resetOwnAnswer() }.value
        } catch {
            Log.error(.app, "\(error)")
        }
    }

    /// Clears every privacy answer macOS has for Flo Tools, then relaunches it: a running process keeps its Accessibility trust until it quits (seen 2026-11-07), and the new copy asks for VoiceOver control and Accessibility at launch. The new copy quits this one (`quitOlderCopies` in main.swift).
    @objc private func resetAllPermissions() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Reset all permissions for Flo Tools?"
        alert.informativeText = "Flo Tools will relaunch and ask for permission to control VoiceOver, then for Accessibility access, which you turn on in System Settings."
        alert.addButton(withTitle: "Reset and Relaunch")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task {
            do {
                try await Task.detached { try PrivacyPermission.all.resetOwnAnswer() }.value
            } catch {
                Log.error(.app, "\(error)")
                await VoiceOver.sayOrLog("Could not reset the permissions.")
                return
            }
            await VoiceOver.sayOrLog("Permissions reset. Relaunching Flo Tools.")
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
                if let error { Log.error(.app, "could not relaunch after resetting the permissions: \(error)") }
            }
        }
    }

    /// Lists the commands the menu counted, of `listedContext`. The status menu does not bring Flo Tools to the front, so that is still the app the user was in.
    @objc private func showActiveCommands() {
        activeCommandsWindow.show(engine.activeCommands(in: listedContext))
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
