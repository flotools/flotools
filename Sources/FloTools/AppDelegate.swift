import AppKit
import FloMacros
import FloToolsCore

/// Menu bar app with no Dock icon. The menu shows status and lets the user turn Flo Tools off.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let engine = FloMacros.makeEngine()
    private var statusItem: NSStatusItem?
    private var accessibilityTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AXElement.setGlobalMessagingTimeout(1.0)
        applyPreferences()
        engine.start()
        setUpStatusItem()

        if !Accessibility.isTrusted(prompt: true) {
            waitForAccessibility()
        }
        // Also makes macOS ask for permission to control VoiceOver on first launch.
        VoiceOver.say("Flo Tools started.")
    }

    private func applyPreferences() {
        DoublePress.shared.timeout = .milliseconds(Preferences.load().timeout)
    }

    private func waitForAccessibility() {
        accessibilityTask?.cancel()
        accessibilityTask = Task { @MainActor in
            while !Task.isCancelled, !Accessibility.isTrusted() {
                try? await Task.sleep(for: .seconds(2))
            }
            guard !Task.isCancelled else { return }
            ContextMonitor.shared.refresh()
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

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
