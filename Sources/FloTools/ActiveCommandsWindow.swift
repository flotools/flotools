import AppKit
import FloEngine
import FloSystem

/// A table of the commands that work in the front window, with their shortcuts. Opened from the count in the status menu. The list is a snapshot taken when the menu item is chosen, because once this window is in front, Pro Tools is not.
@MainActor
final class ActiveCommandsWindow: NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private struct Row {
        let name: String
        let shortcuts: String
    }

    private static let commandColumn = NSUserInterfaceItemIdentifier("command")
    private static let shortcutColumn = NSUserInterfaceItemIdentifier("shortcut")

    private var rows: [Row] = []
    private let table = NSTableView()
    private lazy var window = makeWindow()
    /// Whether the window holds a `BorrowedFocus` loan, so Pro Tools gets the focus back when it closes.
    private var holdsFocus = false

    func show(_ commands: [Command]) {
        rows = commands.map { Row(name: $0.name, shortcuts: $0.triggers.map(\.description).joined(separator: ", ")) }
        _ = window
        window.title = "Active Commands (\(rows.count))"
        table.reloadData()
        if !rows.isEmpty { table.selectRowIndexes([0], byExtendingSelection: false) }
        table.scrollRowToVisible(0)
        if holdsFocus {
            BorrowedFocus.bringToFront()
        } else {
            BorrowedFocus.take()
            holdsFocus = true
        }
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(table)
    }

    @objc private func closeWindow() {
        window.close()
    }

    func windowWillClose(_ notification: Notification) {
        if holdsFocus { BorrowedFocus.giveBack() }
        holdsFocus = false
    }

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn?.identifier else { return nil }
        let text = column == Self.commandColumn ? rows[row].name : rows[row].shortcuts
        let cell = tableView.makeView(withIdentifier: column, owner: self) as? NSTextField ?? NSTextField(labelWithString: "")
        cell.identifier = column
        cell.stringValue = text
        cell.lineBreakMode = .byTruncatingTail
        return cell
    }

    private func makeWindow() -> NSWindow {
        for (identifier, title, width) in [(Self.commandColumn, "Command", 320.0), (Self.shortcutColumn, "Shortcut", 200.0)] {
            let column = NSTableColumn(identifier: identifier)
            column.title = title
            column.width = width
            table.addTableColumn(column)
        }
        table.usesAlternatingRowBackgroundColors = true
        table.dataSource = self
        table.delegate = self
        table.setAccessibilityLabel("Active commands")

        let scroll = NSScrollView.fixed(document: table, size: CGSize(width: 560, height: 420))
        let closeButton = NSButton(title: "Close", target: self, action: #selector(closeWindow))
        closeButton.keyEquivalent = "\u{1b}"
        return NSWindow.floating(title: "Active Commands", views: [scroll, closeButton], alignment: .trailing, delegate: self)
    }
}
