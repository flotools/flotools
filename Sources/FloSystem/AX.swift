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
    public var title: String? { get throws { try string("AXTitle") } }
    public var roleDescription: String? { get throws { try string("AXRoleDescription") } }

    /// What System Events calls `name`.
    public var name: String? { get throws { try title } }

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
    /// Read on the application element: the element that has the keyboard focus.
    public var focusedElement: AXElement? { get throws { try element("AXFocusedUIElement") } }

    // MARK: Queries

    public func children(role: String) throws -> [AXElement] {
        try children.filter { try $0.role == role }
    }

    /// First child with the given role and `AXTitle`, like `groups.byName(...)` in JXA. Searches immediate children only.
    public func child(role: String, name: String) throws -> AXElement? {
        try children.first { try $0.role == role && $0.name == name }
    }

    public var groups: [AXElement] { get throws { try children(role: "AXGroup") } }
    public var buttons: [AXElement] { get throws { try children(role: "AXButton") } }
    public var rows: [AXElement] { get throws { try children(role: "AXRow") } }
    public var sliders: [AXElement] { get throws { try children(role: "AXSlider") } }

    public func group(_ name: String) throws -> AXElement? { try child(role: "AXGroup", name: name) }
    public func button(_ name: String) throws -> AXElement? { try child(role: "AXButton", name: name) }
    public func table(_ name: String) throws -> AXElement? { try child(role: "AXTable", name: name) }

    /// The result of `find`, or `FloError.notFound(what)`. When it is missing and the diagnostic log is on, the log gets a bounded dump of this element, which shows what the app had in place of the expected element.
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
        if Log.isRecording, !Log.skipsDebug { Log.info(.accessibility, "\(what) not found in:\n\(dump())") }
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
        try perform(action, menuMayOpen: true)
    }

    /// Whether this element's app has a pop-up menu window on screen. Window layer and owner are available without Screen Recording permission.
    private func showsPopUpMenu() -> Bool {
        var pid: pid_t = 0
        guard AXUIElementGetPid(ref, &pid) == .success,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return false }
        let menuLayer = Int(CGWindowLevelForKey(.popUpMenuWindow))
        return windows.contains { $0[kCGWindowOwnerPID as String] as? pid_t == pid && $0[kCGWindowLayer as String] as? Int == menuLayer }
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

    /// Role, title, description and value, for the log. Absent attributes are left out, so describing an element never throws.
    public func summary() -> String { describe(until: nil).text }

    /// Reads the summary's attributes until one read fails or `deadline` passes, so a busy app costs at most one messaging timeout. Returns why it stopped, if it did.
    private func describe(until deadline: ContinuousClock.Instant?) -> (text: String, stopped: String?) {
        let fields: [(name: String, format: (String) -> String)] = [
            ("AXRole", { $0 }),
            ("AXSubrole", { "(\($0))" }),
            ("AXTitle", { "title=\($0.debugDescription)" }),
            ("AXDescription", { "desc=\($0.debugDescription)" }),
            ("AXValue", { "value=\($0.debugDescription)" }),
        ]
        var parts: [String] = []
        var stopped: String?
        for field in fields {
            if let deadline, ContinuousClock.now >= deadline { stopped = "time limit"; break }
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(ref, field.name as CFString, &value)
            if Self.readOutcome(result) == .failure { stopped = "AXError \(result.rawValue) reading \(field.name)"; break }
            let text = (value as? String) ?? (value as? NSNumber)?.stringValue
            if let text, !text.isEmpty { parts.append(field.format(text)) }
        }
        return (parts.isEmpty ? "?" : parts.joined(separator: " "), stopped)
    }

    /// Indented tree of this element and its descendants, for the log and porting work. Bounded, because each node costs several messages to a possibly busy app: it stops at `depth` levels, `maxNodes` elements, `maxCharacters` of text or `budget` of time, and at the first read that fails. The time is checked before each read, so one read that is already running can overrun it.
    public func dump(depth: Int = 3, maxNodes: Int = 80, maxCharacters: Int = 8_000, budget: Duration = .milliseconds(500)) -> String {
        var lines: [String] = []
        var characters = 0
        let deadline = ContinuousClock.now + budget
        var stopped: String?
        func visit(_ element: AXElement, level: Int) {
            guard stopped == nil else { return }
            guard lines.count < maxNodes else { stopped = "\(maxNodes) elements"; return }
            guard characters < maxCharacters else { stopped = "\(maxCharacters) characters"; return }
            let description = element.describe(until: deadline)
            let line = String((String(repeating: "  ", count: level) + description.text).prefix(maxCharacters - characters))
            characters += line.count
            lines.append(line)
            if let reason = description.stopped { stopped = reason; return }
            guard level < depth else { return }
            guard ContinuousClock.now < deadline else { stopped = "time limit"; return }
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element.ref, "AXChildren" as CFString, &value)
            guard Self.readOutcome(result) != .failure else { stopped = "AXError \(result.rawValue) reading children"; return }
            for child in (value as? [AXUIElement]) ?? [] { visit(AXElement(child), level: level + 1) }
        }
        visit(self, level: 0)
        if let stopped { lines.append("(dump stopped: \(stopped))") }
        return lines.joined(separator: "\n")
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
