import AppKit
import FloEngine
import FloSystem

/// The preferences window: Launch on Login, the settings of the KM preferences dialog and holding for a double press, with OK and Cancel. Opened from the menu and by the Flo Tools Preferences command. OK saves to the store, then calls `onSave` so the app applies the new values.
@MainActor
final class PreferencesPanel: NSObject, NSWindowDelegate {
    private let store: PreferencesStore
    /// Kept by macOS rather than in `store`, so OK sets it directly.
    private let loginItem: LoginItem
    private let onSave: (Preferences) -> Void
    private lazy var window = makeWindow()
    /// Whether the panel holds a `BorrowedFocus` loan; the app that was in front before it opened, usually Pro Tools, gets the focus back when it closes, as after the KM prompt.
    private var holdsFocus = false

    private let launchOnLogin = NSButton(checkboxWithTitle: "Launch on Login", target: nil, action: nil)
    private let temporaryInspector = NSButton(checkboxWithTitle: "Use temporary inspector", target: nil, action: nil)
    private let startsWithInspector = NSButton(checkboxWithTitle: "Turn on the Flo Tools inspector when Pro Tools starts", target: nil, action: nil)
    private let timeout = NSPopUpButton()
    private let holdForDoublePress = NSButton(checkboxWithTitle: "Hold a key for a double press", target: nil, action: nil)
    private let holdTime = NSPopUpButton()

    init(store: PreferencesStore, loginItem: LoginItem, onSave: @escaping (Preferences) -> Void) {
        self.store = store
        self.loginItem = loginItem
        self.onSave = onSave
    }

    func show() {
        // Make the window first: it adds the timeout and hold time choices, and selecting one before they exist selects nothing, so OK would save the first choice.
        _ = window
        let preferences = store.current
        launchOnLogin.state = loginItem.isEnabled ? .on : .off
        temporaryInspector.state = preferences.temporaryInspector ? .on : .off
        startsWithInspector.state = preferences.startsWithInspector ? .on : .off
        timeout.selectItem(withTag: preferences.timeout)
        holdForDoublePress.state = preferences.holdForDoublePress ? .on : .off
        holdTime.selectItem(withTag: preferences.holdTime)
        if holdsFocus {
            BorrowedFocus.bringToFront()
        } else {
            BorrowedFocus.take()
            holdsFocus = true
        }
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(launchOnLogin)
    }

    @objc private func ok() {
        loginItem.setEnabled(launchOnLogin.state == .on)
        var preferences = Preferences()
        preferences.temporaryInspector = temporaryInspector.state == .on
        preferences.startsWithInspector = startsWithInspector.state == .on
        preferences.timeout = timeout.selectedTag()
        preferences.holdForDoublePress = holdForDoublePress.state == .on
        preferences.holdTime = holdTime.selectedTag()
        store.save(preferences)
        onSave(preferences)
        window.close()
    }

    @objc private func cancel() {
        window.close()
    }

    /// Covers OK, Cancel and the close button.
    func windowWillClose(_ notification: Notification) {
        if holdsFocus { BorrowedFocus.giveBack() }
        holdsFocus = false
    }

    private func makeWindow() -> NSWindow {
        for choice in Preferences.timeoutChoices {
            timeout.addItem(withTitle: "\(choice) ms")
            timeout.lastItem?.tag = choice
        }
        let timeoutLabel = NSTextField(labelWithString: "Double-press timeout:")
        timeout.setAccessibilityTitleUIElement(timeoutLabel)
        for choice in Preferences.holdTimeChoices {
            holdTime.addItem(withTitle: "\(choice) ms")
            holdTime.lastItem?.tag = choice
        }
        let holdTimeLabel = NSTextField(labelWithString: "Hold time:")
        holdTime.setAccessibilityTitleUIElement(holdTimeLabel)


        return NSWindow.floating(title: "Flo Tools Preferences", views: [
            launchOnLogin,
            temporaryInspector,
            startsWithInspector,
            NSStackView(views: [timeoutLabel, timeout]),
            holdForDoublePress,
            NSStackView(views: [holdTimeLabel, holdTime]),
            NSStackView.confirmationButtons(okTitle: "OK", target: self, confirm: #selector(ok), cancel: #selector(cancel)),
        ], alignment: .leading, delegate: self)
    }
}
