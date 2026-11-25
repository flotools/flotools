import AppKit
import FloEngine
import FloProTools
import FloSystem

/// A table of the commands that work in the front window, with their shortcuts, a search field that narrows it and a checkbox that hides the commands limited to the Mix or Edit window. Opened from the count in the status menu. The list is a snapshot taken when the menu item is chosen, because once this window is in front, Pro Tools is not.
@MainActor
final class ActiveCommandsWindow: NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private struct Row {
        let name: String
        let shortcuts: String
        /// The command works only in windows that include Mix or Edit, as Inspector and track commands do.
        let isForMixOrEdit: Bool

        /// Whether every word of `query` is in the name or the shortcuts, ignoring case and accents, so "solo" and "ctrl s" both narrow the list.
        func matches(_ query: String) -> Bool {
            let text = "\(name) \(shortcuts)"
            return query.split(whereSeparator: \.isWhitespace).allSatisfy { word in
                text.range(of: word, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
    }

    private static let commandColumn = NSUserInterfaceItemIdentifier("command")
    private static let shortcutColumn = NSUserInterfaceItemIdentifier("shortcut")

    private var allRows: [Row] = []
    /// The rows that match the search field.
    private var rows: [Row] = []
    private let search = NSSearchField()
    /// Kept between openings while Flo Tools runs.
    private let showMixAndEdit = NSButton(checkboxWithTitle: "Show Mix and Edit window commands", target: nil, action: nil)
    private let table = NSTableView()
    private lazy var window = makeWindow()
    /// Whether the window holds a `BorrowedFocus` loan, so Pro Tools gets the focus back when it closes.
    private var holdsFocus = false

    func show(_ commands: [Command]) {
        allRows = commands.map { command in
            Row(name: command.name,
                shortcuts: command.triggers.map(\.description).joined(separator: ", "),
                isForMixOrEdit: command.scope.isLimited(toInclude: .mix) || command.scope.isLimited(toInclude: .edit))
        }
        _ = window
        window.title = "Active Commands (\(allRows.count))"
        search.stringValue = ""
        narrow()
        if holdsFocus {
            BorrowedFocus.bringToFront()
        } else {
            BorrowedFocus.take()
            holdsFocus = true
        }
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(search)
    }

    /// Shows the rows that match the search field and the checkbox, with the first one selected, so Tab from the field lands on a match.
    @objc private func narrow() {
        let query = search.stringValue
        let showsMixAndEdit = showMixAndEdit.state == .on
        rows = allRows.filter { $0.matches(query) && (showsMixAndEdit || !$0.isForMixOrEdit) }
        table.reloadData()
        if !rows.isEmpty { table.selectRowIndexes([0], byExtendingSelection: false) }
        table.scrollRowToVisible(0)
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

        search.placeholderString = "Search commands and shortcuts"
        search.setAccessibilityLabel("Search active commands")
        search.target = self
        search.action = #selector(narrow)
        search.translatesAutoresizingMaskIntoConstraints = false
        search.widthAnchor.constraint(equalToConstant: 560).isActive = true

        showMixAndEdit.state = .on
        showMixAndEdit.target = self
        showMixAndEdit.action = #selector(narrow)

        let scroll = NSScrollView.fixed(document: table, size: CGSize(width: 560, height: 420))
        let closeButton = NSButton(title: "Close", target: self, action: #selector(closeWindow))
        closeButton.keyEquivalent = "\u{1b}"
        return NSWindow.floating(title: "Active Commands", views: [search, showMixAndEdit, scroll, closeButton], alignment: .leading, delegate: self)
    }
}
