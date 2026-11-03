import AppKit
import ApplicationServices

/// A thin wrapper around `AXUIElement` with the lookups the System Events scripts used.
///
/// System Events terms map to AX like this: `name` is `AXTitle`, `value` is `AXValue`, `groups` are children with role `AXGroup`, `buttons` are `AXButton`, `popUpButtons` are `AXPopUpButton`, `uiElements` are all children.
public struct AXElement: Equatable, CustomStringConvertible {
    public let ref: AXUIElement

    public init(_ ref: AXUIElement) { self.ref = ref }

    public static func application(pid: pid_t) -> AXElement { AXElement(AXUIElementCreateApplication(pid)) }
    public static var systemWide: AXElement { AXElement(AXUIElementCreateSystemWide()) }

    /// Limits how long any AX call may block when the target app is busy.
    public static func setGlobalMessagingTimeout(_ seconds: Float) {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), seconds)
    }

    public static func == (a: AXElement, b: AXElement) -> Bool { CFEqual(a.ref, b.ref) }

    // MARK: Attributes

    public func raw(_ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(ref, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    public func string(_ attribute: String) -> String? { raw(attribute) as? String }

    public func element(_ attribute: String) -> AXElement? {
        guard let value = raw(attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return AXElement(unsafeDowncast(value, to: AXUIElement.self))
    }

    public func elements(_ attribute: String) -> [AXElement] {
        guard let value = raw(attribute) as? [AXUIElement] else { return [] }
        return value.map(AXElement.init)
    }

    public var role: String? { string("AXRole") }
    public var subrole: String? { string("AXSubrole") }
    public var title: String? { string("AXTitle") }
    public var axDescription: String? { string("AXDescription") }
    public var help: String? { string("AXHelp") }

    /// What System Events calls `name`.
    public var name: String? { title }

    /// `AXValue` as text. Numbers are converted, other types give nil.
    public var value: String? {
        guard let value = raw("AXValue") else { return nil }
        if let s = value as? String { return s }
        if let n = value as? NSNumber { return n.stringValue }
        return nil
    }

    public var children: [AXElement] { elements("AXChildren") }
    public var windows: [AXElement] { elements("AXWindows") }
    public var focusedWindow: AXElement? { element("AXFocusedWindow") }
    public var focusedElement: AXElement? { element("AXFocusedUIElement") }

    public var pid: pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(ref, &pid) == .success ? pid : nil
    }

    // MARK: Queries

    public func children(role: String) -> [AXElement] { children.filter { $0.role == role } }

    /// First child with the given role and `AXTitle`, like `groups.byName(...)` in JXA.
    public func child(role: String, name: String) -> AXElement? {
        children.first { $0.role == role && $0.name == name }
    }

    public var groups: [AXElement] { children(role: "AXGroup") }
    public var buttons: [AXElement] { children(role: "AXButton") }
    public var popUpButtons: [AXElement] { children(role: "AXPopUpButton") }
    public var tables: [AXElement] { children(role: "AXTable") }
    public var rows: [AXElement] { children(role: "AXRow") }

    public func group(_ name: String) -> AXElement? { child(role: "AXGroup", name: name) }
    public func button(_ name: String) -> AXElement? { child(role: "AXButton", name: name) }
    public func popUpButton(_ name: String) -> AXElement? { child(role: "AXPopUpButton", name: name) }
    public func table(_ name: String) -> AXElement? { child(role: "AXTable", name: name) }

    // MARK: Actions

    @discardableResult
    public func perform(_ action: String) -> Bool {
        AXUIElementPerformAction(ref, action as CFString) == .success
    }

    /// Same as `click()` on a System Events button.
    @discardableResult
    public func press() -> Bool { perform("AXPress") }

    @discardableResult
    public func set(_ attribute: String, to value: CFTypeRef) -> Bool {
        AXUIElementSetAttributeValue(ref, attribute as CFString, value) == .success
    }

    // MARK: Debugging

    public var description: String {
        var parts = [role ?? "?"]
        if let subrole { parts.append("(\(subrole))") }
        if let title, !title.isEmpty { parts.append("title=\(title.debugDescription)") }
        if let axDescription, !axDescription.isEmpty { parts.append("desc=\(axDescription.debugDescription)") }
        if let value, !value.isEmpty { parts.append("value=\(value.debugDescription)") }
        return parts.joined(separator: " ")
    }

    /// Indented tree of this element and its descendants, for porting work.
    public func dump(depth: Int = 3, indent: String = "") -> String {
        var out = indent + description + "\n"
        guard depth > 0 else { return out }
        for child in children { out += child.dump(depth: depth - 1, indent: indent + "  ") }
        return out
    }
}

public enum Accessibility {
    /// Whether this app may use the Accessibility API. With `prompt`, macOS shows its permission dialog when not yet allowed.
    @discardableResult
    public static func isTrusted(prompt: Bool = false) -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": prompt] as CFDictionary)
    }
}
