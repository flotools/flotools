import AppKit

extension NSWindow {
    /// The window of Flo Tools' own dialogs: titled and closable, above Pro Tools, centered, with `views` in one vertical stack. Not released when closed, because its controller keeps it and is told of the close through `delegate`.
    @MainActor
    public static func floating(title: String, views: [NSView], alignment: NSLayoutConstraint.Attribute, delegate: NSWindowDelegate) -> NSWindow {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = alignment
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = title
        window.contentView = stack
        // Above Pro Tools, as the Keyboard Maestro prompts and AppleScript lists were.
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.delegate = delegate
        window.center()
        return window
    }
}

extension NSScrollView {
    /// A vertically scrolling view of `document` with a fixed size, as the chooser and the text window show their content.
    @MainActor
    static func fixed(document: NSView, size: CGSize) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.documentView = document
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.widthAnchor.constraint(equalToConstant: size.width).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: size.height).isActive = true
        return scroll
    }
}

extension NSStackView {
    /// Cancel, answering Escape, then the confirm button `okTitle`, answering Return, as Flo Tools' dialogs end.
    @MainActor
    public static func confirmationButtons(okTitle: String, target: AnyObject, confirm: Selector, cancel: Selector) -> NSStackView {
        let cancelButton = NSButton(title: "Cancel", target: target, action: cancel)
        cancelButton.keyEquivalent = "\u{1b}"
        let okButton = NSButton(title: okTitle, target: target, action: confirm)
        okButton.keyEquivalent = "\r"
        return NSStackView(views: [cancelButton, okButton])
    }
}
