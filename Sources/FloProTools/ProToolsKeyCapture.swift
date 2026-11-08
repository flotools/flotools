import Foundation
import FloSystem

/// What takes Pro Tools' keys away from the control the VoiceOver cursor is on.
public enum KeyCapture: Sendable, Equatable, CustomStringConvertible {
    case menu
    case textField

    public var description: String {
        switch self {
        case .menu: "a menu is open"
        case .textField: "a text field is open for typing"
        }
    }
}

/// What the front app's notifications said about menus and fields open for typing. Pure, so the rules are tested without AX.
struct KeyCaptureEvents {
    /// The front app that reported AXMenuOpened and no AXMenuClosed since, or 0.
    private(set) var menuOpenedPid: pid_t = 0
    /// The element of the front app's last AXSelectedTextChanged, which may be a counter open for typing. Cleared when the app's focused element changes, which closing a counter causes and opening one does not. A Mix comments field kept AXFocused set after its editor closed (seen live 2026-11-07), so the flag alone could keep keys captured.
    private(set) var selectedTextSource: (pid: pid_t, element: AXElementHandle)?
    /// Counts changes, so a check that waited on a read can tell whether a menu or field opened meanwhile.
    private(set) var revision = 0

    /// Records `event` from app `pid`. Events from any app but `front` are ignored: while the observer moves to a new front app, the old one can still send some.
    mutating func record(_ event: FrontWindowEvent, from pid: pid_t, front: pid_t) {
        guard pid == front, pid > 0 else { return }
        switch event {
        case .menuOpened: menuOpenedPid = pid
        case .menuClosed: menuOpenedPid = 0
        case .selectedTextChanged(let element): selectedTextSource = (pid, element)
        case .focusedElementChanged: selectedTextSource = nil
        case .windowMayHaveChanged: return
        }
        revision += 1
    }

    /// Another app came to the front, which closes its menus, or monitoring stopped.
    mutating func reset() {
        menuOpenedPid = 0
        selectedTextSource = nil
        revision += 1
    }

    func counter(of pid: pid_t) -> AXElementHandle? {
        selectedTextSource.flatMap { $0.pid == pid ? $0.element : nil }
    }
}

/// Whether Pro Tools has a menu or a field open for typing, which take its keys. Pro Tools opens counters and value fields for typing without making them the focused element, so this combines the front app's notifications, which `ContextMonitor` passes on from its one observer, with two AX reads at key time.
///
/// Owned by the main actor, which receives the notifications. Inactive until `start()` and after `stop()`; an inactive check finds nothing.
@MainActor
public final class ProToolsKeyCapture {
    /// The reads a check makes. Tests replace them to drive the check without Pro Tools.
    struct Reads: Sendable {
        var showsPopUpMenu: @Sendable (pid_t) -> Bool
        var isTyping: @Sendable (pid_t, AXElementHandle?) async throws -> Bool

        static let live = Reads(
            showsPopUpMenu: { AXElement.showsPopUpMenu(pid: $0) },
            isTyping: { try await ProToolsKeyCapture.isTyping(pid: $0, counter: $1) }
        )
    }

    private var events = KeyCaptureEvents()
    private var isActive = false
    private let reads: Reads

    public convenience init() { self.init(reads: .live) }

    init(reads: Reads) { self.reads = reads }

    public func start() { isActive = true }

    public func stop() {
        isActive = false
        events.reset()
    }

    /// Another app came to the front, which closes the old one's menus and fields.
    public func frontAppChanged() { events.reset() }

    /// A notification from app `pid` while `front` is in front.
    public func record(_ event: FrontWindowEvent, from pid: pid_t, front: pid_t) {
        events.record(event, from: pid, front: front)
    }

    /// What takes app `pid`'s keys now, nil when nothing does or capture is inactive.
    ///
    /// A menu is open when the app reported AXMenuOpened and no AXMenuClosed since, or shows a pop-up menu window. The notification arrives before the window is on screen (27 ms before it, measured 2026-11-07), and the window check covers a menu that opened before the observer was attached.
    ///
    /// A text field is open for typing when the app's focused element is a text entry, as the editor a Mix comments field opens is, or when the element of the last AXSelectedTextChanged, with no focus change since, is a text field with its focus flag set, as a counter opened for typing is. Both are read now rather than tracked.
    ///
    /// Throws when the app's focused element cannot be read, as while Pro Tools is busy, because then nobody knows whether a field is open; and when menus or fields keep changing during the check.
    public func check(pid: pid_t) async throws -> KeyCapture? {
        guard isActive, pid > 0 else { return nil }
        // A menu or field can open while the focus is read, so the check starts over when a notification came meanwhile.
        for _ in 0..<3 {
            let revision = events.revision
            if events.menuOpenedPid == pid || reads.showsPopUpMenu(pid) { return .menu }
            if try await reads.isTyping(pid, events.counter(of: pid)) { return .textField }
            if events.revision == revision { return nil }
        }
        throw FloError.couldNot("check for an open menu or text field, which kept changing")
    }

    @AccessibilityActor
    private static func isTyping(pid: pid_t, counter: AXElementHandle?) throws -> Bool {
        if try ProToolsApp(pid: pid).hasTextEntryFocus() { return true }
        guard let counter else { return false }
        do {
            return try ProToolsApp.isOpenForTyping(counter.element)
        } catch {
            // Usually a field whose window closed; it cannot be typed into.
            Log.debug(.context, "could not read the last selected text field: \(error)")
            return false
        }
    }
}
