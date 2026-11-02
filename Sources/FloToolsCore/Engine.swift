import Foundation
import os

public struct HotKeyTrigger: Sendable, Equatable {
    public let combo: KeyCombo
    /// Keyboard Maestro's "is released" fire type.
    public let onRelease: Bool

    public init(_ combo: KeyCombo, onRelease: Bool) {
        self.combo = combo
        self.onRelease = onRelease
    }
}

/// A macro from the Keyboard Maestro export.
public struct MacroInfo: Sendable, Equatable {
    public let uid: String
    public let name: String
    public let group: String
    public let enabledByDefault: Bool
    public let hotKeys: [HotKeyTrigger]
    /// Non-hotkey triggers, for example "FocussedWindow FocussedWindowChanges". Kept for reference.
    public let otherTriggers: [String]

    public init(uid: String, name: String, group: String, enabledByDefault: Bool, hotKeys: [HotKeyTrigger], otherTriggers: [String]) {
        self.uid = uid
        self.name = name
        self.group = group
        self.enabledByDefault = enabledByDefault
        self.hotKeys = hotKeys
        self.otherTriggers = otherTriggers
    }
}

public typealias MacroAction = @MainActor () -> Void

/// Connects hotkeys to ported macro actions, honoring group app and window conditions like Keyboard Maestro.
/// Macros without a Swift action are not registered, so their keys stay free.
@MainActor
public final class MacroEngine {
    public static let shared = MacroEngine()

    public let groups: [String: MacroGroup]
    public let macros: [MacroInfo]
    public var isEnabled = true {
        didSet { updateHotKeys() }
    }

    private let log = Logger(subsystem: "com.chikim.FloTools", category: "engine")
    private var actions: [String: MacroAction] = [:]
    private var groupEnabled: [String: Bool]
    private var macroEnabled: [String: Bool]
    private var context = FrontContext()
    private var started = false

    public init(groups: [MacroGroup] = Catalog.groups, macros: [MacroInfo] = Catalog.macros) {
        self.groups = Dictionary(groups.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        self.macros = macros
        groupEnabled = Dictionary(groups.map { ($0.name, $0.enabledByDefault) }, uniquingKeysWith: { first, _ in first })
        macroEnabled = Dictionary(macros.map { ($0.uid, $0.enabledByDefault) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: Setup

    /// Attaches the Swift implementation of a macro, by its Keyboard Maestro UID.
    public func register(_ uid: String, _ action: @escaping MacroAction) {
        precondition(macros.contains { $0.uid == uid }, "unknown macro UID \(uid)")
        actions[uid] = action
        if started { updateHotKeys() }
    }

    public var portedMacros: [MacroInfo] { macros.filter { actions[$0.uid] != nil } }

    public func macro(named name: String) -> MacroInfo? { macros.first { $0.name == name } }

    public func start() {
        guard !started else { return }
        started = true
        HotKeyCenter.shared.handler = { [weak self] combo, event in self?.handle(combo, event) }
        let monitor = ContextMonitor.shared
        monitor.onChange = { [weak self] context in
            self?.context = context
            self?.updateHotKeys()
        }
        monitor.start()
        context = monitor.current
        updateHotKeys()
    }

    // MARK: State, like Keyboard Maestro's group and macro enable actions

    public func isGroupEnabled(_ name: String) -> Bool { groupEnabled[name] ?? false }

    public func setGroup(_ name: String, enabled: Bool) {
        groupEnabled[name] = enabled
        updateHotKeys()
    }

    public func setMacro(_ uid: String, enabled: Bool) {
        macroEnabled[uid] = enabled
        updateHotKeys()
    }

    /// Runs a macro directly, like Keyboard Maestro's Execute Macro action.
    public func run(_ uid: String) {
        guard let action = actions[uid] else {
            log.error("macro \(uid, privacy: .public) is not ported")
            return
        }
        action()
    }

    // MARK: Matching

    /// Macros that would fire for this key in this context, best match first.
    public func candidates(for combo: KeyCombo, onRelease: Bool, in context: FrontContext) -> [MacroInfo] {
        macros
            .filter { macro in
                actions[macro.uid] != nil
                    && macroEnabled[macro.uid] == true
                    && groupEnabled[macro.group] == true
                    && groups[macro.group]?.applies(to: context) == true
                    && macro.hotKeys.contains { $0.combo == combo && $0.onRelease == onRelease }
            }
            .sorted { (groups[$0.group]?.specificity ?? 0) > (groups[$1.group]?.specificity ?? 0) }
    }

    public func activeCombos(in context: FrontContext) -> Set<KeyCombo> {
        var combos = Set<KeyCombo>()
        for macro in macros where actions[macro.uid] != nil && macroEnabled[macro.uid] == true && groupEnabled[macro.group] == true {
            guard groups[macro.group]?.applies(to: context) == true else { continue }
            for trigger in macro.hotKeys { combos.insert(trigger.combo) }
        }
        return combos
    }

    private func updateHotKeys() {
        guard started else { return }
        HotKeyCenter.shared.setActive(isEnabled ? activeCombos(in: context) : [])
    }

    private func handle(_ combo: KeyCombo, _ event: HotKeyEvent) {
        // The window may have changed since the keys were registered, so check again.
        context = ContextMonitor.shared.refresh()
        let onRelease = event == .released
        guard isEnabled, let macro = candidates(for: combo, onRelease: onRelease, in: context).first else {
            if !onRelease && candidates(for: combo, onRelease: true, in: context).isEmpty {
                log.notice("no macro for \(combo.description, privacy: .public), passing it on")
                HotKeyCenter.shared.passThrough(combo)
            }
            updateHotKeys()
            return
        }
        log.notice("\(combo.description, privacy: .public) -> \(macro.group, privacy: .public)/\(macro.name, privacy: .public)")
        actions[macro.uid]?()
    }
}
