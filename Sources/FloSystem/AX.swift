import AppKit
import ApplicationServices

/// The one executor for Accessibility calls into other apps. A busy Pro Tools can block an AX call for up to the messaging timeout; on this actor that wait holds up other AX work, not hotkeys, the menu or speech on the main actor.
@globalActor
public actor AccessibilityActor {
    public static let shared = AccessibilityActor()
}

/// An element of another app's user interface, wrapped so it is used only on `AccessibilityActor`.
///
/// System Events terms map to AX like this: `name` is `AXTitle`, `value` is `AXValue`, `groups` are children with role `AXGroup`, `buttons` are `AXButton`, `popUpButtons` are `AXPopUpButton`, `uiElements` are all children.
///
/// Reads return nil only when the element has no such attribute or no value. Every other failure throws `FloError.accessibility`, so a command never mistakes a busy or closed window for an empty value.
@AccessibilityActor
public struct AXElement {
    /// Kept private and actor-isolated: `AXUIElement` is not `Sendable`, and Apple does not document concurrent use.
    private let ref: AXUIElement

    init(_ ref: AXUIElement) { self.ref = ref }

    public static func application(pid: pid_t) -> AXElement { AXElement(AXUIElementCreateApplication(pid)) }

    /// Limits how long any AX call may block when the target app is busy.
    public nonisolated static func setGlobalMessagingTimeout(_ seconds: Float) {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), seconds)
    }

    /// The process that has keyboard focus. Usually the active app, but not always: the Dock under VoiceOver (VO+D) and Spotlight take the keyboard while the app behind them stays active (checked live 2026-11-08). Throws `FloError.accessibility` when it cannot be read. Answered in 0.4 to 17 ms in those checks; it is called from the hotkey callback, so a slow answer delays the key.
    public nonisolated static func keyboardFocusProcess() throws -> pid_t {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedApplicationAttribute as CFString, &value)
        var pid: pid_t = 0
        guard result == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID(), AXUIElementGetPid(value as! AXUIElement, &pid) == .success else {
            throw FloError.accessibility(operation: "read the focused application", code: result.rawValue)
        }
        return pid
    }

    /// Whether both wrap the same element. Not `Equatable`, because comparing needs the actor.
    public func isSame(as other: AXElement) -> Bool { CFEqual(ref, other.ref) }

    // MARK: Reads

    /// The attribute's value, nil when the element has no such attribute or it has no value. Other failures throw, among them a window that closed (`invalidUIElement`) and a busy app (`cannotComplete`).
    private func attribute(_ name: String) throws -> CFTypeRef? {
        let start = ContinuousClock.now
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(ref, name as CFString, &value)
        switch Self.readOutcome(result) {
        case .value:
            Log.debug(.accessibility, "read \(name): \(value.map(Self.preview) ?? "nil") (\(Log.elapsed(since: start)))")
            return value
        case .absent:
            Log.debug(.accessibility, "read \(name): none, AXError \(result.rawValue) (\(Log.elapsed(since: start)))")
            return nil
        case .failure:
            // Debug, not warning: the thrown error carries the same operation and code, and whoever handles it logs it once, the engine for a command and the context monitor for its repeating window reads.
            Log.debug(.accessibility, "read \(name) failed: AXError \(result.rawValue) (\(Log.elapsed(since: start)))")
            throw FloError.accessibility(operation: "read \(name)", code: result.rawValue)
        }
    }

    /// A short form of a read value for the log, so a run of AXTitle and AXValue reads shows which control each was. Only built while the log is on, since `Log.debug` takes its message lazily.
    nonisolated static func preview(_ value: CFTypeRef) -> String {
        if let text = value as? String { return text.count > 60 ? "\"\(text.prefix(60))...\"" : "\"\(text)\"" }
        if let number = value as? NSNumber { return number.stringValue }
        if let list = value as? [Any] { return "\(list.count) items" }
        if CFGetTypeID(value) == AXUIElementGetTypeID() { return "an element" }
        if CFGetTypeID(value) == AXValueGetTypeID() { return "a geometry value" }
        return "a value of another type"
    }

    public enum ReadOutcome: Equatable, Sendable {
        case value, absent, failure
    }

    /// How a read's `AXError` is treated. Only "no such attribute" and "no value" are absence; anything else means the read did not work.
    public nonisolated static func readOutcome(_ result: AXError) -> ReadOutcome {
        switch result {
        case .success: .value
        case .noValue, .attributeUnsupported: .absent
        default: .failure
        }
    }

    public func string(_ name: String) throws -> String? {
        guard let value = try attribute(name) else { return nil }
        guard let text = value as? String else { throw FloError.unexpectedValue("\(name) is not text") }
        return text
    }

    public func element(_ name: String) throws -> AXElement? {
        guard let value = try attribute(name) else { return nil }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { throw FloError.unexpectedValue("\(name) is not an element") }
        return AXElement(unsafeDowncast(value, to: AXUIElement.self))
    }

    /// An absent list is an empty one.
    public func elements(_ name: String) throws -> [AXElement] {
        guard let value = try attribute(name) else { return [] }
        guard let refs = value as? [AXUIElement] else { throw FloError.unexpectedValue("\(name) is not a list of elements") }
        return refs.map(AXElement.init)
    }

    public func bool(_ name: String) throws -> Bool? {
        guard let value = try attribute(name) else { return nil }
        guard let number = value as? NSNumber else { throw FloError.unexpectedValue("\(name) is not a Boolean") }
        return number.boolValue
    }

    public var role: String? { get throws { try string("AXRole") } }
    public var roleDescription: String? { get throws { try string("AXRoleDescription") } }
    /// The element's own keyboard focus flag, which can be set when the app's focused element is something else.
    public var isFocused: Bool { get throws { try bool("AXFocused") ?? false } }

    /// The element's AXTitle, which System Events and the JXA call its name.
    public var name: String? { get throws { try string("AXTitle") } }

    /// `AXValue` as text; numbers are converted. An empty string stays empty, which for a Solo button means off.
    public var value: String? {
        get throws {
            guard let value = try attribute("AXValue") else { return nil }
            if let text = value as? String { return text }
            if let number = value as? NSNumber { return number.stringValue }
            throw FloError.unexpectedValue("AXValue is neither text nor a number")
        }
    }

    /// What VoiceOver reads for a slider, for example "70 to the left" for a pan knob.
    public var valueDescription: String? { get throws { try string("AXValueDescription") } }

    /// The top-left corner in global screen coordinates (origin at the top left of the main display), the coordinates mouse events use.
    public var position: CGPoint? { get throws { try geometry("AXPosition", .cgPoint, CGPoint.zero) } }

    /// The width and height in screen points.
    public var size: CGSize? { get throws { try geometry("AXSize", .cgSize, CGSize.zero) } }

    /// Position and size as one rectangle, nil when either is absent. A failed read throws.
    public var frame: CGRect? {
        get throws {
            guard let origin = try position, let size = try size else { return nil }
            return CGRect(origin: origin, size: size)
        }
    }

    /// Position and size as one rectangle, or `FloError.notFound` naming the position or size of `what` that is missing.
    public func requiredFrame(of what: String) throws -> CGRect {
        CGRect(origin: try position.required("the position of \(what)"), size: try size.required("the size of \(what)"))
    }

    private func geometry<T: BitwiseCopyable>(_ name: String, _ type: AXValueType, _ empty: T) throws -> T? {
        guard let value = try attribute(name) else { return nil }
        var result = empty
        guard CFGetTypeID(value) == AXValueGetTypeID(), AXValueGetValue(unsafeDowncast(value, to: AXValue.self), type, &result) else {
            throw FloError.unexpectedValue("\(name) is not a \(T.self)")
        }
        return result
    }

    /// False for a dimmed menu item or button; an element without `AXEnabled` counts as enabled.
    public var isEnabled: Bool { get throws { try bool("AXEnabled") ?? true } }

    /// The check mark of a menu item, nil when it is not checked.
    public var menuItemMark: String? { get throws { try string("AXMenuItemMarkChar") } }

    public var children: [AXElement] { get throws { try elements("AXChildren") } }
    public var windows: [AXElement] { get throws { try elements("AXWindows") } }
    public var focusedWindow: AXElement? { get throws { try element("AXFocusedWindow") } }
    /// A window's close button; dialogs usually have none.
    public var closeButton: AXElement? { get throws { try element("AXCloseButton") } }
    /// Read on the application element: the element that has the keyboard focus.
    public var focusedElement: AXElement? { get throws { try element("AXFocusedUIElement") } }

    // MARK: Queries

    public func children(role: String) throws -> [AXElement] {
        try children.filter { try $0.role == role }
    }

    /// First child with the given role and `AXTitle`, like `groups.byName(...)` in JXA. Searches immediate children only.
    ///
    /// The name is read first and the role only for a match: in a window of track strips almost every child is a group, so role first would read nearly every child twice (Audio 200 of 220: 19 ms role first, 13 ms name first, measured 2026-11-08).
    public func child(role: String, name: String) throws -> AXElement? {
        try child(role: role, name: name, tryingFirst: nil)?.element
    }

    /// `child(role:name:)` that checks the child at `index` first, for scans of many containers laid out alike, such as the Solo button of every track strip: a right guess costs two reads instead of one per child before it. Returns the child's index, to guess with in the next container. If two children match, a right guess may return a later one than the search would.
    public func child(role: String, name: String, tryingFirst index: Int?) throws -> (element: AXElement, index: Int)? {
        let children = try self.children
        func matches(_ child: AXElement) throws -> Bool { try child.name == name && child.role == role }
        if let index, children.indices.contains(index), try matches(children[index]) { return (children[index], index) }
        return try children.firstIndex(where: matches).map { (children[$0], $0) }
    }

    public var groups: [AXElement] { get throws { try children(role: "AXGroup") } }
    public var buttons: [AXElement] { get throws { try children(role: "AXButton") } }
    public var rows: [AXElement] { get throws { try children(role: "AXRow") } }
    public var sliders: [AXElement] { get throws { try children(role: "AXSlider") } }

    public func group(_ name: String) throws -> AXElement? { try child(role: "AXGroup", name: name) }
    public func button(_ name: String) throws -> AXElement? { try child(role: "AXButton", name: name) }
    public func table(_ name: String) throws -> AXElement? { try child(role: "AXTable", name: name) }

    /// The result of `find`, or `FloError.notFound(what)`. When it is missing and the diagnostic log is on, the log gets the attributes of this element and its children, which show what the app had in place of the expected element.
    ///
    /// Every lookup that a command cannot continue without goes through here, so the debug line at its end names what the attribute reads before it were looking for.
    public func required(_ what: @autoclosure () -> String, _ find: (AXElement) throws -> AXElement?) throws -> AXElement {
        let start = ContinuousClock.now
        let found: AXElement?
        do {
            found = try find(self)
        } catch {
            Log.debug(.accessibility, "looking for \(what()) failed (\(Log.elapsed(since: start))): \(error)")
            throw error
        }
        if let found {
            Log.debug(.accessibility, "found \(what()) (\(Log.elapsed(since: start)))")
            return found
        }
        let what = what()
        // Not inside a watch's poll: a watch on a missing element would dump it ten times a second (seen live 2026-11-03: 1762 dumps in five minutes). The watch logs its own failures.
        if Log.isRecording, !Log.skipsDebug { Log.info(.accessibility, "\(what) not found in:\n\(attributeDump())") }
        throw FloError.notFound(what)
    }

    // MARK: Actions

    /// Performs an AX action. A failure throws. `cannotComplete` may still have taken effect, so callers must not retry toggles.
    public func perform(_ action: String) throws { try perform(action, menuMayOpen: false) }

    private func perform(_ action: String, menuMayOpen: Bool) throws {
        let start = ContinuousClock.now
        let result = AXUIElementPerformAction(ref, action as CFString)
        if result == .success {
            Log.info(.accessibility, "\(action) on \(summary()) (\(Log.elapsed(since: start)))")
        } else if menuMayOpen, result == .cannotComplete, showsPopUpMenu() {
            Log.info(.accessibility, "\(action) on \(summary()) opened a pop-up menu; the app answers when it closes (\(Log.elapsed(since: start)))")
        } else {
            // Info, not warning: the thrown error reaches whoever owns the failure, usually the engine, which logs it once. This line keeps which element it was.
            Log.info(.accessibility, "\(action) on \(summary()) failed: AXError \(result.rawValue) (\(Log.elapsed(since: start)))")
            throw FloError.accessibility(operation: action, code: result.rawValue)
        }
    }

    /// Same as `click()` on a System Events button.
    public func press() throws { try perform("AXPress") }

    /// Presses a button that may open a pop-up menu, such as a Pro Tools insert or send selector. Pro Tools answers that press only once the menu closes, so the press times out while the menu is open (measured 2026-11-02: AXError -25204 after the timeout, menu window on screen). With this element's timeout cut to 0.25 s, a timeout counts as done when the app then shows a pop-up menu window; otherwise it throws as a busy app. A press that opens a plug-in window instead returned at once (11 ms).
    public func pressOpeningMenu() throws { try performOpeningMenu("AXPress") }

    /// Opens the element's context menu, like a right click, with the same timeout handling as `pressOpeningMenu()`.
    public func showMenu() throws { try performOpeningMenu("AXShowMenu") }

    private func performOpeningMenu(_ action: String) throws {
        AXUIElementSetMessagingTimeout(ref, 0.25)
        // 0 puts the element back on the global timeout, in case the caller uses it again.
        defer { AXUIElementSetMessagingTimeout(ref, 0) }
        try perform(action, menuMayOpen: true)
    }

    /// Whether this element's app has a pop-up menu window on screen.
    private func showsPopUpMenu() -> Bool {
        var pid: pid_t = 0
        guard AXUIElementGetPid(ref, &pid) == .success else { return false }
        return Self.showsPopUpMenu(pid: pid)
    }

    /// Whether app `pid` has a pop-up menu window on screen. Window layer and owner are available without Screen Recording permission, and reading them sends the app nothing, so this never blocks on a busy app.
    public nonisolated static func showsPopUpMenu(pid: pid_t) -> Bool {
        !popUpMenuWindows(pid: pid).isEmpty
    }

    /// The element under a screen point, only when it belongs to the intended app.
    public static func at(_ point: CGPoint, pid: pid_t) throws -> AXElement? {
        var ref: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &ref)
        guard result == .success else { throw FloError.accessibility(operation: "read the element under the pointer", code: result.rawValue) }
        guard let ref else { return nil }
        var owner: pid_t = 0
        guard AXUIElementGetPid(ref, &owner) == .success, owner == pid else { return nil }
        return AXElement(ref)
    }

    /// Native context menus may be absent from the app's AX children. Hit-testing their own window finds the menu without guessing an item's position.
    public static func popUpMenu(pid: pid_t) async throws -> AXElement {
        let start = ContinuousClock.now
        while true {
            do {
                var busy: FloError?
                for window in popUpMenuWindows(pid: pid) {
                    guard let bounds = window[kCGWindowBounds as String] as? [String: Any],
                          let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary), frame.height > 10 else { continue }
                    let points = [CGPoint(x: frame.midX, y: frame.midY),
                                  CGPoint(x: frame.midX, y: frame.minY + 10),
                                  CGPoint(x: frame.midX, y: frame.maxY - 10)]
                    for point in points {
                        do {
                            if let menu = try menu(at: point, pid: pid) { return menu }
                        } catch let error as FloError where error.isBusyApp {
                            // VoiceOver's caption panel can obscure a point in the menu.
                            busy = error
                        }
                    }
                }
                if let busy { throw busy }
                throw FloError.notFound("the pop-up menu")
            } catch let error as FloError where error.isBusyApp && ContinuousClock.now - start < .seconds(1) {
                // A menu window can exist before its Accessibility objects answer.
                try await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private static func menu(at point: CGPoint, pid: pid_t) throws -> AXElement? {
        guard let hit = try at(point, pid: pid) else { return nil }
        let menu = try hit.role == "AXMenu" ? hit : hit.element("AXParent")
        guard let menu, try menu.role == "AXMenu" else { return nil }
        var owner: pid_t = 0
        guard AXUIElementGetPid(menu.ref, &owner) == .success, owner == pid else { return nil }
        return menu
    }

    private nonisolated static func popUpMenuWindows(pid: pid_t) -> [[String: Any]] {
        guard pid > 0, let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return [] }
        let layer = Int(CGWindowLevelForKey(.popUpMenuWindow))
        return windows.filter { $0[kCGWindowOwnerPID as String] as? pid_t == pid && $0[kCGWindowLayer as String] as? Int == layer }
    }

    /// Moves a slider one step, as `increment()` and `decrement()` on a System Events slider.
    public func step(_ direction: SliderStep) throws {
        switch direction {
        case .increase: try perform("AXIncrement")
        case .decrease: try perform("AXDecrement")
        }
    }

    // MARK: Notifications, for FrontWindowObserver

    /// The `AXError` of the registration; `.success` when it worked.
    func addNotification(_ name: String, to observer: AXObserver, refcon: UnsafeMutableRawPointer) -> AXError {
        AXObserverAddNotification(observer, ref, name as CFString, refcon)
    }

    func removeNotification(_ name: String, from observer: AXObserver) {
        AXObserverRemoveNotification(observer, ref, name as CFString)
    }

    // MARK: Diagnostics

    /// Role, title, description and value, for the log. Absent attributes are left out, so describing an element never throws. Stops at the first read that fails, so a busy app costs at most one messaging timeout.
    public func summary() -> String {
        let fields: [(name: String, format: (String) -> String)] = [
            ("AXRole", { $0 }),
            ("AXSubrole", { "(\($0))" }),
            ("AXTitle", { "title=\($0.debugDescription)" }),
            ("AXDescription", { "desc=\($0.debugDescription)" }),
            ("AXValue", { "value=\($0.debugDescription)" }),
        ]
        var parts: [String] = []
        for field in fields {
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(ref, field.name as CFString, &value)
            if Self.readOutcome(result) == .failure { break }
            let text = (value as? String) ?? (value as? NSNumber)?.stringValue
            if let text, !text.isEmpty { parts.append(field.format(text)) }
        }
        return parts.isEmpty ? "?" : parts.joined(separator: " ")
    }

    /// One child as `attributeDump` sees it before reading it in full, for a rule that picks which children to dump. Read in one message.
    public struct DumpChild: Sendable, Equatable {
        public let role: String?
        public let identifier: String?
        public let isSelected: Bool

        init(role: String?, identifier: String?, isSelected: Bool) {
            self.role = role
            self.identifier = identifier
            self.isSelected = isSelected
        }

        @AccessibilityActor fileprivate init(_ element: AXElement) {
            let names = ["AXRole", "AXIdentifier", "AXSelected"]
            var values: CFArray?
            // A failed read leaves every field empty; the child is then dumped or left out by role alone, and its own dump shows the error.
            let read = AXUIElementCopyMultipleAttributeValues(element.ref, names as CFArray, [], &values) == .success ? (values as [AnyObject]?) ?? [] : []
            func value(_ index: Int) -> AnyObject? { read.indices.contains(index) ? read[index] : nil }
            self.init(role: value(0) as? String, identifier: value(1) as? String, isSelected: (value(2) as? Bool) == true)
        }
    }

    /// How many elements in a row `attributeDump` may fail to read before it stops.
    static let maxFailuresInRow = 3

    /// Every attribute with a value of this element and of its descendants down to `depth` levels, with their parameterized attributes and actions. Used for the log where a lookup stopped (one level), and for a whole window when the log is turned off. It shows everything an app exposes, such as an identifier or value that appears only later.
    ///
    /// `keep`, when given, gets an element and its children and returns the indices of the children to dump; each run of the others becomes one line saying they were left out. Without it, every child is dumped without the extra read. Bounded, because each element costs four messages to a possibly busy app: it stops at `maxCharacters` of text, at `budget` of time and after `maxFailuresInRow` elements in a row could not be read. One element that cannot be read gets a line saying so, and the dump goes on with the next, because an element can vanish while a window is dumped, such as a row that scrolled away; several in a row mean the app has stopped answering, and each further read could wait out the messaging timeout. The time is checked before each element, so one read that is already running can overrun it.
    public func attributeDump(depth: Int = 1, maxCharacters: Int = 30_000, budget: Duration = .seconds(1), keep: ((_ parent: DumpChild, _ children: [DumpChild]) -> Set<Int>)? = nil) -> String {
        let deadline = ContinuousClock.now + budget
        var lines: [String] = []
        var characters = 0
        var stopped: String?
        var failuresInRow = 0
        func visit(_ element: AXElement, _ seen: DumpChild?, level: Int) {
            let indent = String(repeating: "  ", count: level)
            let read = element.attributeLines(indent: indent)
            lines += read.lines
            characters += read.lines.reduce(0) { $0 + $1.count + 1 }
            if let failure = read.failure {
                lines.append("\(indent)(could not read: \(failure))")
                failuresInRow += 1
                if failuresInRow >= Self.maxFailuresInRow { stopped = "\(failuresInRow) elements in a row could not be read" }
                return
            }
            failuresInRow = 0
            let children = read.children
            guard level < depth, !children.isEmpty else { return }
            let summaries = keep == nil ? [] : children.map(DumpChild.init)
            let kept = keep.map { $0(seen ?? DumpChild(element), summaries) } ?? Set(children.indices)
            var index = 0
            while index < children.count {
                guard stopped == nil else { return }
                guard ContinuousClock.now < deadline else { stopped = "time limit"; return }
                guard characters < maxCharacters else { stopped = "\(maxCharacters) characters"; return }
                if kept.contains(index) {
                    lines.append("\(indent)child \(index + 1) of \(children.count):")
                    visit(children[index], summaries.isEmpty ? nil : summaries[index], level: level + 1)
                    index += 1
                } else {
                    let first = index
                    while index < children.count, !kept.contains(index) { index += 1 }
                    let run = first + 1 == index ? "child \(index)" : "children \(first + 1) to \(index)"
                    lines.append("\(indent)\(run) of \(children.count) left out")
                }
            }
        }
        visit(self, nil, level: 0)
        if let stopped { lines.append("(attribute dump stopped: \(stopped))") }
        return String(lines.joined(separator: "\n").prefix(maxCharacters))
    }

    /// One line per attribute, then the parameterized attributes and actions, and the children read on the way. `failure` says why the attributes could not be read.
    private func attributeLines(indent: String) -> (lines: [String], children: [AXElement], failure: String?) {
        var names: CFArray?
        let namesResult = AXUIElementCopyAttributeNames(ref, &names)
        guard namesResult == .success, let names = names as? [String] else {
            return ([], [], "AXError \(namesResult.rawValue) reading attribute names")
        }
        // One message for all values; a value that could not be read comes back as an AXError value.
        var values: CFArray?
        let valuesResult = AXUIElementCopyMultipleAttributeValues(ref, names as CFArray, [], &values)
        guard valuesResult == .success, let values = values as [AnyObject]?, values.count == names.count else {
            return ([], [], "AXError \(valuesResult.rawValue) reading attribute values")
        }
        var lines: [String] = []
        var children: [AXElement] = []
        for (name, value) in zip(names, values) {
            if name == "AXChildren", let list = value as? [AXUIElement] { children = list.map(AXElement.init) }
            if Self.isAbsent(value) { continue }
            lines.append("\(indent)\(name) = \(Self.fullDescription(value))")
        }
        var parameterized: CFArray?
        if AXUIElementCopyParameterizedAttributeNames(ref, &parameterized) == .success, let list = parameterized as? [String], !list.isEmpty {
            lines.append("\(indent)parameterized: \(list.joined(separator: ", "))")
        }
        var actions: CFArray?
        if AXUIElementCopyActionNames(ref, &actions) == .success, let list = actions as? [String], !list.isEmpty {
            lines.append("\(indent)actions: \(list.joined(separator: ", "))")
        }
        return (lines, children, nil)
    }

    /// An attribute value in full for the attribute dump, where `preview` would hide the detail being looked for. Elements are not read further, so describing one costs no message.
    nonisolated static func fullDescription(_ value: AnyObject) -> String {
        if let text = value as? String {
            // Line breaks are escaped so a value stays on its line and the indentation keeps showing the tree.
            let shown = text.prefix(300).replacingOccurrences(of: "\n", with: "\\n")
            return text.count > 300 ? "\"\(shown)...\"" : "\"\(shown)\""
        }
        if CFGetTypeID(value) == CFBooleanGetTypeID() { return (value as? Bool) == true ? "true" : "false" }
        if let number = value as? NSNumber { return number.stringValue }
        if CFGetTypeID(value) == AXUIElementGetTypeID() { return "an element" }
        if CFGetTypeID(value) == AXValueGetTypeID() { return axValueDescription(unsafeDowncast(value, to: AXValue.self)) }
        if let list = value as? [AnyObject] {
            guard !list.isEmpty, list.count <= 20, list.allSatisfy({ CFGetTypeID($0) != AXUIElementGetTypeID() }) else {
                return "\(list.count) items"
            }
            return "[" + list.map(fullDescription).joined(separator: ", ") + "]"
        }
        if let url = value as? URL { return url.absoluteString }
        return String(describing: value)
    }

    /// Whether a value from a multiple-attribute read stands for an attribute with no value or one the element does not support, which the attribute dump leaves out. Other errors stay, because they mean the read failed.
    nonisolated static func isAbsent(_ value: AnyObject) -> Bool {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return false }
        let axValue = unsafeDowncast(value, to: AXValue.self)
        var error = AXError.success
        guard AXValueGetType(axValue) == .axError, AXValueGetValue(axValue, .axError, &error) else { return false }
        return readOutcome(error) == .absent
    }

    private nonisolated static func axValueDescription(_ value: AXValue) -> String {
        switch AXValueGetType(value) {
        case .cgPoint:
            var point = CGPoint.zero
            AXValueGetValue(value, .cgPoint, &point)
            return "point(\(point.x), \(point.y))"
        case .cgSize:
            var size = CGSize.zero
            AXValueGetValue(value, .cgSize, &size)
            return "size(\(size.width), \(size.height))"
        case .cgRect:
            var rect = CGRect.zero
            AXValueGetValue(value, .cgRect, &rect)
            return "rect(\(rect.origin.x), \(rect.origin.y), \(rect.width), \(rect.height))"
        case .cfRange:
            var range = CFRange()
            AXValueGetValue(value, .cfRange, &range)
            return "range(\(range.location), \(range.length))"
        case .axError:
            var error = AXError.success
            AXValueGetValue(value, .axError, &error)
            return "(AXError \(error.rawValue))"
        default:
            return "an AX value of another type"
        }
    }
}

public enum Accessibility {
    /// Whether this app may use the Accessibility API. With `prompt`, macOS shows its permission dialog when not yet allowed.
    @discardableResult
    public static func isTrusted(prompt: Bool = false) -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": prompt] as CFDictionary)
    }
}

/// Which way `AXElement.step(_:)` moves a slider. For a pan knob, increase is to the right.
public enum SliderStep: Sendable {
    case increase, decrease
}

/// The element an AX notification came from, carried from the main thread, where notifications arrive, to `AccessibilityActor`, where it is read. Unchecked because `AXUIElement` is not marked `Sendable`: CF retain and release are thread-safe, and the reference is only opened, and so only messaged, on `AccessibilityActor`.
public struct AXElementHandle: @unchecked Sendable {
    private let ref: AXUIElement

    init(_ ref: AXUIElement) { self.ref = ref }

    @AccessibilityActor public var element: AXElement { AXElement(ref) }
}
