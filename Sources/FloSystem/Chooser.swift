import AppKit

/// A list to pick items from, like AppleScript's `choose from list`, which the KM version used: a window with a prompt, a list, Cancel and a named OK button. VoiceOver reads it as a normal window with a table.
@MainActor
public enum Chooser {
    /// What to show. `title` is the window title, `prompt` the text above the list.
    public struct Request: Sendable {
        public var title: String
        public var prompt: String
        public var items: [String]
        public var okTitle = "OK"
        public var allowsMultipleSelection = true

        public init(title: String, prompt: String, items: [String], okTitle: String = "OK", allowsMultipleSelection: Bool = true) {
            self.title = title
            self.prompt = prompt
            self.items = items
            self.okTitle = okTitle
            self.allowsMultipleSelection = allowsMultipleSelection
        }
    }

    /// The index of the first item that starts with `typed`, ignoring case and diacritics.
    nonisolated static func firstMatch(_ typed: String, in items: [String]) -> Int? {
        items.firstIndex { $0.range(of: typed, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil }
    }

    /// Shows the list and returns the indices of the chosen items in list order, or an empty array when the user cancels. Cancelling the calling task closes the window. The app that was in front gets the focus back.
    public static func choose(_ request: Request) async -> [Int] {
        let window = ChooserWindow(request)
        return await withTaskCancellationHandler {
            await window.run()
        } onCancel: {
            Task { @MainActor in window.finish(with: []) }
        }
    }
}

/// One chooser window. It keeps itself alive until it finishes.
@MainActor
private final class ChooserWindow: NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let request: Chooser.Request
    private let table = NSTableView()
    private var window: NSWindow?
    private var continuation: CheckedContinuation<[Int], Never>?
    private var finished = false

    init(_ request: Chooser.Request) {
        self.request = request
    }

    func run() async -> [Int] {
        // A run cancelled before the window opened shows nothing.
        guard !finished, !Task.isCancelled else { return [] }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            let window = makeWindow()
            self.window = window
            BorrowedFocus.take()
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(table)
            if !request.items.isEmpty { table.selectRowIndexes([0], byExtendingSelection: false) }
        }
    }

    func finish(with indices: [Int]) {
        guard !finished else { return }
        finished = true
        window?.delegate = nil
        window?.close()
        BorrowedFocus.giveBack()
        continuation?.resume(returning: indices)
        continuation = nil
    }

    @objc private func ok() { finish(with: table.selectedRowIndexes.sorted()) }
    @objc private func cancel() { finish(with: []) }

    /// The close button cancels.
    func windowWillClose(_ notification: Notification) { finish(with: []) }

    func numberOfRows(in tableView: NSTableView) -> Int { request.items.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        NSTextField(labelWithString: request.items[row])
    }

    /// Typing a name moves to it, as in `choose from list`.
    func tableView(_ tableView: NSTableView, typeSelectStringFor tableColumn: NSTableColumn?, row: Int) -> String? {
        request.items[row]
    }

    /// The first item that starts with the typed text. NSTableView's own search starts after the selected row, so typing the name of the selected item moved away from it (checked live 2026-11-02).
    func tableView(_ tableView: NSTableView, nextTypeSelectMatchFromRow startRow: Int, toRow endRow: Int, for searchString: String) -> Int {
        Chooser.firstMatch(searchString, in: request.items) ?? -1
    }

    private func makeWindow() -> NSWindow {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("item"))
        column.title = request.prompt
        table.addTableColumn(column)
        table.headerView = nil
        table.allowsMultipleSelection = request.allowsMultipleSelection
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(ok)
        table.setAccessibilityLabel(request.prompt)

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.widthAnchor.constraint(equalToConstant: 360).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 300).isActive = true

        let prompt = NSTextField(wrappingLabelWithString: request.prompt)
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.keyEquivalent = "\u{1b}"
        let okButton = NSButton(title: request.okTitle, target: self, action: #selector(ok))
        okButton.keyEquivalent = "\r"

        return NSWindow.floating(title: request.title, views: [prompt, scroll, NSStackView(views: [cancelButton, okButton])], alignment: .leading, delegate: self)
    }
}

/// Brings Flo Tools to the front for windows of its own and later gives the focus back to the app that was in front, usually Pro Tools. Focus belongs to the whole app, so the loan is one shared count: while windows follow each other, such as the two choosers of List Tracks with Flo Tools, the focus stays with Flo Tools and goes back once, when the last holder returns it.
@MainActor
public enum BorrowedFocus {
    private static var previous: NSRunningApplication?
    private static var holders = 0

    /// Holds the loan and brings Flo Tools to the front. Each call needs one `giveBack()`.
    public static func take() {
        hold()
        bringToFront()
    }

    /// Brings Flo Tools to the front, for a window that already holds the loan.
    public static func bringToFront() {
        // Not the macOS 14 `activate()`: that one is cooperative and stays in the background unless the request follows a user event Flo Tools itself received. A hotkey qualifies; an Accessibility press on the status menu, which is how VoiceOver chooses a menu item, does not (checked live 2026-11-02). The deprecated call still activates.
        NSApp.activate(ignoringOtherApps: true)
    }

    public static func giveBack() {
        guard holders > 0 else { return }
        holders -= 1
        guard holders == 0 else { return }
        previous?.activate()
        previous = nil
    }

    /// Keeps the loan for the duration of `body` without bringing Flo Tools to the front, so windows that `body` opens one after another share it.
    public nonisolated static func holding<T: Sendable>(_ body: () async throws -> T) async throws -> T {
        await hold()
        do {
            let result = try await body()
            await giveBack()
            return result
        } catch {
            await giveBack()
            throw error
        }
    }

    private static func hold() {
        if holders == 0 {
            let front = NSWorkspace.shared.frontmostApplication
            previous = front == .current ? nil : front
        }
        holders += 1
    }
}
