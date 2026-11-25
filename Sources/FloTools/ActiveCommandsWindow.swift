import AppKit
import FloEngine
import FloProTools
import FloSystem

/// A table of the commands that work in the front window, with their shortcuts, a search field that narrows it and a checkbox that hides the commands limited to the Mix or Edit window. Opened from the count in the status menu, with the commands the menu counted.
@MainActor
final class ActiveCommandsWindow: NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private static let commandColumn = NSUserInterfaceItemIdentifier("command")
    private static let shortcutColumn = NSUserInterfaceItemIdentifier("shortcut")
    private static let width: CGFloat = 560

    private var allCommands: [Command] = []
    /// The commands that pass the search field and the checkbox.
    private var shown: [Command] = []
    private let search = NSSearchField()
    /// How many commands are shown, also spoken when the search or the checkbox changes it, because the user is in the field, not the table.
    private let resultCount = NSTextField(labelWithString: "")
    private var speakResult: Task<Void, Never>?
    /// Kept between openings while Flo Tools runs.
    private let mixAndEditCheckbox = NSButton(checkboxWithTitle: "Show Mix and Edit window commands", target: nil, action: nil)
    private let table = NSTableView()
    private lazy var window = makeWindow()
    private var focusLoan = FocusLoan()

    func show(_ commands: [Command]) {
        allCommands = commands
        // A new list starts at its first row.
        shown = []
        _ = window
        window.title = "Active Commands (\(commands.count))"
        search.stringValue = ""
        updateShown()
        focusLoan.bringForward()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(search)
    }

    /// The search text or the checkbox changed. Speaks the count once typing pauses for a second: after half a second, VoiceOver's last phrase was still the typed letter. Spoken through VoiceOver's `output`, as elsewhere in Flo Tools, because an accessibility announcement posted here never became VoiceOver's last phrase (both checked live 2026-11-25).
    @objc private func narrow() {
        updateShown()
        let text = resultCount.stringValue
        speakResult?.cancel()
        speakResult = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await VoiceOver.sayOrLog(text)
        }
    }

    /// Filters the commands and keeps the selected one selected if it is still shown, else selects the first.
    private func updateShown() {
        let selected = shown.indices.contains(table.selectedRow) ? shown[table.selectedRow].id : nil
        let query = search.stringValue
        let showsMixAndEdit = mixAndEditCheckbox.state == .on
        shown = allCommands.filter { command in
            command.matches(search: query) && (showsMixAndEdit || !command.scope.isLimited(toAnyOf: [.mix, .edit]))
        }
        table.reloadData()
        resultCount.stringValue = resultText
        guard !shown.isEmpty else { return }
        let row = shown.firstIndex { $0.id == selected } ?? 0
        table.selectRowIndexes([row], byExtendingSelection: false)
        table.scrollRowToVisible(row)
    }

    private var resultText: String {
        if allCommands.isEmpty { return "No commands are active in the front window." }
        if shown.isEmpty { return "No commands match." }
        return "\(shown.count) of \(allCommands.count) commands"
    }

    @objc private func closeWindow() {
        window.close()
    }

    func windowWillClose(_ notification: Notification) {
        speakResult?.cancel()
        focusLoan.end()
    }

    func numberOfRows(in tableView: NSTableView) -> Int { shown.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn?.identifier else { return nil }
        let text = column == Self.commandColumn ? shown[row].name : shown[row].shortcutText
        let cell = tableView.makeView(withIdentifier: column, owner: self) as? NSTextField ?? {
            let label = NSTextField(labelWithString: "")
            label.identifier = column
            label.lineBreakMode = .byTruncatingTail
            return label
        }()
        cell.stringValue = text
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
        search.widthAnchor.constraint(equalToConstant: Self.width).isActive = true

        mixAndEditCheckbox.state = .on
        mixAndEditCheckbox.target = self
        mixAndEditCheckbox.action = #selector(narrow)

        let scroll = NSScrollView.fixed(document: table, size: CGSize(width: Self.width, height: 420))
        let closeButton = NSButton(title: "Close", target: self, action: #selector(closeWindow))
        // Escape closes the window. With text in the search field, the first Escape clears the field instead (checked live 2026-11-25).
        closeButton.keyEquivalent = "\u{1b}"
        return NSWindow.floating(title: "Active Commands", views: [search, resultCount, mixAndEditCheckbox, scroll, closeButton], alignment: .leading, delegate: self)
    }
}
