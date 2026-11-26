import AppKit
import FloEngine
import FloSystem

/// A table of the commands that work in the front window, with their shortcuts, a search field that narrows it and a checkbox that shows only the commands for the current window, hiding those that work in any Pro Tools window. Opened from the count in the status menu, with the commands the menu counted. Execute, the default button, closes the window and runs the selected command.
@MainActor
final class ActiveCommandsWindow: NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
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
    private let currentWindowOnlyCheckbox = NSButton(checkboxWithTitle: "Show only commands for the current window", target: nil, action: nil)
    private let table = NSTableView()
    private let executeButton = NSButton(title: "Execute", target: nil, action: nil)
    private lazy var window: NSWindow = makeWindow()
    private var focusLoan = FocusLoan()
    /// Runs the chosen command, after the window has closed.
    private let execute: (CommandID) -> Void

    init(execute: @escaping (CommandID) -> Void) {
        self.execute = execute
    }

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
        let currentWindowOnly = currentWindowOnlyCheckbox.state == .on
        shown = allCommands.filter { command in
            command.matches(search: query) && (!currentWindowOnly || command.scope.isLimitedToWindowKinds)
        }
        table.reloadData()
        resultCount.stringValue = resultText
        updateExecuteButton()
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

    private var selectedCommand: Command? {
        shown.indices.contains(table.selectedRow) ? shown[table.selectedRow] : nil
    }

    /// Execute is dimmed while no command is selected.
    private func updateExecuteButton() {
        executeButton.isEnabled = selectedCommand != nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateExecuteButton()
    }

    /// Closes the window first, so the focus goes back to the window the command acts on.
    @objc private func executeSelected() {
        guard let command = selectedCommand else { return }
        window.close()
        execute(command.id)
    }

    /// Return in the search field executes too, and Escape in the empty field closes the window. The field takes both keys for itself before the default button or the window sees them (checked live 2026-11-26); Escape with text still clears the field.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            executeSelected()
            return true
        case #selector(NSResponder.cancelOperation(_:)) where search.stringValue.isEmpty:
            window.close()
            return true
        default:
            return false
        }
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

    private func makeWindow() -> EscapeClosingWindow {
        for (identifier, title, width) in [(Self.commandColumn, "Command", 320.0), (Self.shortcutColumn, "Shortcut", 200.0)] {
            let column = NSTableColumn(identifier: identifier)
            column.title = title
            column.width = width
            table.addTableColumn(column)
        }
        table.usesAlternatingRowBackgroundColors = true
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(executeSelected)
        table.setAccessibilityLabel("Active commands")

        search.placeholderString = "Search commands and shortcuts"
        search.setAccessibilityLabel("Search active commands")
        search.target = self
        search.delegate = self
        search.action = #selector(narrow)
        search.translatesAutoresizingMaskIntoConstraints = false
        search.widthAnchor.constraint(equalToConstant: Self.width).isActive = true

        currentWindowOnlyCheckbox.target = self
        currentWindowOnlyCheckbox.action = #selector(narrow)

        let scroll = NSScrollView.fixed(document: table, size: CGSize(width: Self.width, height: 420))
        executeButton.target = self
        executeButton.action = #selector(executeSelected)
        // Return executes the selected command.
        executeButton.keyEquivalent = "\r"
        return EscapeClosingWindow.floating(title: "Active Commands", views: [search, resultCount, currentWindowOnlyCheckbox, scroll, executeButton], alignment: .leading, delegate: self)
    }
}

/// Closes on Escape. The window has no Cancel or Close button to carry Escape as a key equivalent, so the key reaches the window through the responder chain, for example from the table (checked live 2026-11-26).
private final class EscapeClosingWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        performClose(sender)
    }
}
