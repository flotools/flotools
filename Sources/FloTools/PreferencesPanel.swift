import AppKit
import FloEngine
import FloSystem

/// The preferences window: the settings of the KM preferences dialog, with OK and Cancel. Opened from the menu and by the Flo Tools Preferences macro. OK saves to the store, then calls `onSave` so the app applies the new values.
@MainActor
final class PreferencesPanel: NSObject, NSWindowDelegate {
    private let store: PreferencesStore
    private let onSave: (Preferences) -> Void
    private lazy var window = makeWindow()
    /// Whether the panel holds a `BorrowedFocus` loan; the app that was in front before it opened, usually Pro Tools, gets the focus back when it closes, as after the KM prompt.
    private var holdsFocus = false

    private let temporaryInspector = NSButton(checkboxWithTitle: "Use temporary inspector", target: nil, action: nil)
    private let startsWithInspector = NSButton(checkboxWithTitle: "Turn on the Flo Tools inspector when Pro Tools starts", target: nil, action: nil)
    private let timeout = NSPopUpButton()

    init(store: PreferencesStore, onSave: @escaping (Preferences) -> Void) {
        self.store = store
        self.onSave = onSave
    }

    func show() {
        // Make the window first: it adds the timeout choices, and selecting one before they exist selects nothing, so OK would save the first choice.
        _ = window
        let preferences = store.current
        temporaryInspector.state = preferences.temporaryInspector ? .on : .off
        startsWithInspector.state = preferences.startsWithInspector ? .on : .off
        timeout.selectItem(withTag: preferences.timeout)
        if holdsFocus {
            BorrowedFocus.bringToFront()
        } else {
            BorrowedFocus.take()
            holdsFocus = true
        }
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(temporaryInspector)
    }

    @objc private func ok() {
        var preferences = Preferences()
        preferences.temporaryInspector = temporaryInspector.state == .on
        preferences.startsWithInspector = startsWithInspector.state == .on
        preferences.timeout = timeout.selectedTag()
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

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.keyEquivalent = "\u{1b}"
        let okButton = NSButton(title: "OK", target: self, action: #selector(ok))
        okButton.keyEquivalent = "\r"

        let stack = NSStackView(views: [
            temporaryInspector,
            startsWithInspector,
            NSStackView(views: [timeoutLabel, timeout]),
            NSStackView(views: [cancelButton, okButton]),
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Flo Tools Preferences"
        window.contentView = stack
        // Above Pro Tools, as the KM prompt was floating.
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }
}
