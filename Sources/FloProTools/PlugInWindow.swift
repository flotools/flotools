import CoreGraphics
import FloSystem

/// A Pro Tools plug-in window ("Plug-in: EQ3 7-Band") or AudioSuite window ("Audio Suite: Reverse"). Both have a preset pop-up button with next and previous buttons beside it; their names differ in capitals and wording, so each kind names its own.
@AccessibilityActor
public struct PlugInWindow {
    public enum Kind: Sendable {
        case plugIn, audioSuite

        /// The start of the window title, which is also the condition of the KM group.
        public var titlePrefix: String {
            switch self {
            case .plugIn: "Plug-in:"
            case .audioSuite: "Audio Suite:"
            }
        }

        /// How `ProToolsWindowKind` classifies a window of this kind.
        var windowKind: ProToolsWindowKind {
            switch self {
            case .plugIn: .plugIn
            case .audioSuite: .audioSuite
            }
        }

        var what: String {
            switch self {
            case .plugIn: "a plug-in window"
            case .audioSuite: "an AudioSuite window"
            }
        }

        var presetMenu: String {
            switch self {
            case .plugIn: "Librarian menu"
            case .audioSuite: "Preset"
            }
        }
    }

    public enum PresetStep: Sendable {
        case next, previous

        /// The same in both window kinds in Pro Tools 26.10 (checked live 2026-11-03). The JXA used "Next Setting" for AudioSuite, which no longer matches.
        var buttonTitle: String {
            switch self {
            case .next: "Next setting"
            case .previous: "Previous setting"
            }
        }
    }

    /// A control of the plug-in itself: a slider in the window's "FXTDMEditView" group. `value` is what VoiceOver reads, such as "-3.0 dB".
    public struct Parameter: Sendable, Equatable {
        public let name: String
        public let value: String
    }

    public let kind: Kind
    private let element: AXElement

    init(_ kind: Kind, _ element: AXElement) {
        self.kind = kind
        self.element = element
    }

    public var title: String { get throws { try element.title ?? "" } }

    /// The plug-in's name: the window title without "Plug-in: ".
    public var plugInName: String {
        get throws { Self.plugInName(fromTitle: try title, kind: kind) }
    }

    public nonisolated static func plugInName(fromTitle title: String, kind: Kind) -> String {
        var name = title
        if name.hasPrefix(kind.titlePrefix + " ") { name.removeFirst(kind.titlePrefix.count + 1) }
        return name
    }

    /// The window's top-left corner on screen, which positions in view files are relative to.
    public var origin: CGPoint {
        get throws { try element.position.required("the position of the \(kind == .plugIn ? "plug-in" : "AudioSuite") window") }
    }

    /// Presses the window's button called `name`, such as "Render".
    public func press(_ name: String) throws {
        try button(name).press()
    }

    /// The name of the current preset.
    public var preset: String {
        get throws { try presetMenu().value ?? "" }
    }

    /// Goes to the next or previous preset and returns its name, once Pro Tools shows it.
    public func step(_ step: PresetStep) async throws -> String {
        let menu = try presetMenu()
        let before = try menu.value ?? ""
        try press(step.buttonTitle)
        return try await ProToolsUpdate.reading(changedFrom: before) { try menu.value ?? "" }
    }

    /// Opens the preset menu, for VoiceOver to choose from.
    public func openPresetMenu() throws {
        try presetMenu().pressOpeningMenu()
    }

    /// Whether the plug-in's Effect Bypass button is on. Its value contains "on" when it is.
    public var isBypassed: Bool {
        get throws { try (bypassButton().value ?? "").contains("on") }
    }

    /// Switches the bypass and returns the new state, once Pro Tools shows it. The JXA waited 0.1 s.
    public func toggleBypass() async throws -> Bool {
        let button = try bypassButton()
        let before = try button.value ?? ""
        try button.press()
        return try await ProToolsUpdate.reading(changedFrom: before) { try button.value ?? "" }.contains("on")
    }

    /// The plug-in's sliders in window order, skipping those without a name.
    public func parameters() throws -> [Parameter] {
        try parameterSliders().compactMap { slider in
            guard let name = try slider.name else { return nil }
            return Parameter(name: name, value: try slider.valueDescription ?? "")
        }
    }

    /// What VoiceOver reads for the parameter called `name`, nil when the plug-in shows no such slider.
    public func parameterValue(named name: String) throws -> String? {
        try parameterSliders().first { try $0.name == name }?.valueDescription
    }

    private func parameterSliders() throws -> [AXElement] {
        try element.required("the plug-in controls") { try $0.group("FXTDMEditView") }.sliders
    }

    private func button(_ name: String) throws -> AXElement {
        try element.required("the \(name) button") { try $0.button(name) }
    }

    private func bypassButton() throws -> AXElement { try button("Effect Bypass") }

    private func presetMenu() throws -> AXElement {
        try element.required("the preset menu") { try $0.child(role: "AXPopUpButton", name: kind.presetMenu) }
    }
}

extension ProToolsApp {
    /// The front window, which must be a plug-in or AudioSuite window as `ProToolsWindowKind` classifies it. The commands that use it run only while such a window is in front, and the front one is the instance the user is working in, also when two windows of one plug-in have the same title. The JXA took the first window with the title prefix instead.
    @AccessibilityActor
    public func plugInWindow(_ kind: PlugInWindow.Kind) throws -> PlugInWindow {
        let front = try AXElement.application(pid: pid).required(kind.what) { try $0.focusedWindow }
        guard ProToolsWindowKind(title: try front.title ?? "") == kind.windowKind else { throw FloError.notFound(kind.what) }
        return PlugInWindow(kind, front)
    }
}
