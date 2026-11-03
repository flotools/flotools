import AppKit

/// A window that shows text to read and copy, like Keyboard Maestro's "display results in a window". VoiceOver reads it as a text area. It keeps itself alive until closed, and does not hold up the macro that opened it.
@MainActor
public enum TextWindow {
    /// The open windows, so each stays alive until the user closes it.
    fileprivate static var open: [TextWindowController] = []

    /// Shows `text` in a new window above the app in front, with the text selected for copying.
    public static func show(title: String, text: String) {
        let shown = TextWindowController()
        open.append(shown)
        shown.show(title: title, text: text)
    }
}

@MainActor
private final class TextWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show(title: String, text: String) {
        let textView = NSTextView()
        textView.string = text
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.setAccessibilityLabel(title)

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        textView.autoresizingMask = [.width]
        textView.frame = NSRect(x: 0, y: 0, width: 520, height: 360)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.widthAnchor.constraint(equalToConstant: 520).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 360).isActive = true

        let close = NSButton(title: "Close", target: self, action: #selector(closeWindow))
        close.keyEquivalent = "\u{1b}"

        let stack = NSStackView(views: [scroll, close])
        stack.orientation = .vertical
        stack.alignment = .trailing
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = title
        window.contentView = stack
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window

        BorrowedFocus.take()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
        textView.selectAll(nil)
    }

    @objc private func closeWindow() { window?.close() }

    func windowWillClose(_ notification: Notification) {
        window?.delegate = nil
        BorrowedFocus.giveBack()
        TextWindow.open.removeAll { $0 === self }
    }
}
