import AppKit
import FloEngine
import FloSystem

/// The preferences window: Launch on Login and the hold time, with OK and Cancel. Opened from the menu and by the Flo Tools Preferences command. OK saves to the store, then calls `onSave` so the app applies the new values.
@MainActor
final class PreferencesPanel: NSObject, NSWindowDelegate {
    private let store: PreferencesStore
    /// Kept as a launch agent file rather than in `store`, so OK sets it directly.
    private let loginItem: LoginItem
    private let onSave: (Preferences) -> Void
    private lazy var window = makeWindow()
    /// The app that was in front before the panel opened, usually Pro Tools, gets the focus back when it closes, as after the KM prompt.
    private var focusLoan = FocusLoan()

    private let launchOnLogin = NSButton(checkboxWithTitle: "Launch on Login", target: nil, action: nil)
    private let holdTime = NSPopUpButton()
    private let holdTimeLabel = NSTextField(labelWithString: "Hold time:")

    init(store: PreferencesStore, loginItem: LoginItem, onSave: @escaping (Preferences) -> Void) {
        self.store = store
        self.loginItem = loginItem
        self.onSave = onSave
    }

    func show() {
        // Make the window first: it adds the hold time choices, and selecting one before they exist selects nothing, so OK would save the first choice.
        _ = window
        let preferences = store.current
        launchOnLogin.state = loginItem.isEnabled ? .on : .off
        holdTime.selectItem(withTag: preferences.holdTime)
        focusLoan.bringForward()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(launchOnLogin)
    }

    @objc private func ok() {
        loginItem.setEnabled(launchOnLogin.state == .on)
        var preferences = Preferences()
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
        focusLoan.end()
    }

    private func makeWindow() -> NSWindow {
        for choice in Preferences.holdTimeChoices {
            holdTime.addItem(withTitle: "\(choice) ms")
            holdTime.lastItem?.tag = choice
        }
        holdTime.setAccessibilityTitleUIElement(holdTimeLabel)
        return NSWindow.floating(title: "Flo Tools Preferences", views: [
            launchOnLogin,
            NSStackView(views: [holdTimeLabel, holdTime]),
            NSStackView.confirmationButtons(okTitle: "OK", target: self, confirm: #selector(ok), cancel: #selector(cancel)),
        ], alignment: .leading, delegate: self)
    }
}
