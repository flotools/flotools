import Foundation
import os
import FloSystem

/// Connects hotkeys to installed macros, honoring group app and window conditions like Keyboard Maestro.
/// Only installed macros take keys, so other keys stay free.
@MainActor
public final class MacroEngine {
    public let groups: [MacroGroupID: MacroGroup]
    public private(set) var macros: [Macro] = []
    public var isEnabled = true {
        didSet { updateHotKeys() }
    }

    private let log = Logger(subsystem: "com.chikim.FloTools", category: "engine")
    private var macroIndex: [MacroID: Int] = [:]
    private var groupEnabled: [MacroGroupID: Bool]
    private var groupActivated: [MacroGroupID: Bool]
    private var macroEnabled: [MacroID: Bool] = [:]
    /// The front app and window, refreshed before each hotkey runs its macro.
    public private(set) var context = FrontContext()
    private var started = false

    public init(groups: [MacroGroup]) {
        self.groups = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })
        groupEnabled = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0.enabledByDefault) })
        groupActivated = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, true) })
    }

    // MARK: Setup

    public func install(_ macro: Macro) {
        precondition(groups[macro.group] != nil, "macro \(macro.id) has unknown group \(macro.group)")
        precondition(macroIndex[macro.id] == nil, "macro \(macro.id) installed twice")
        macroIndex[macro.id] = macros.count
        macros.append(macro)
        macroEnabled[macro.id] = macro.enabledByDefault
        if started { updateHotKeys() }
    }

    public func macro(_ id: MacroID) -> Macro? { macroIndex[id].map { macros[$0] } }

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

    public func isGroupEnabled(_ id: MacroGroupID) -> Bool { groupEnabled[id] ?? false }

    public func setGroup(_ id: MacroGroupID, enabled: Bool) {
        precondition(groups[id] != nil, "unknown group \(id)")
        groupEnabled[id] = enabled
        updateHotKeys()
    }

    /// Whether the group is activated, like Keyboard Maestro's Activate/Deactivate Macro Group action. This is separate from enabled: Toggle Inspector activates and deactivates the Inspector group, while Flo Tools' own on/off switch enables and disables groups. Groups start activated.
    public func isGroupActivated(_ id: MacroGroupID) -> Bool { groupActivated[id] ?? false }

    public func setGroup(_ id: MacroGroupID, activated: Bool) {
        precondition(groups[id] != nil, "unknown group \(id)")
        groupActivated[id] = activated
        updateHotKeys()
    }

    public func isMacroEnabled(_ id: MacroID) -> Bool { macroEnabled[id] ?? false }

    public func setMacro(_ id: MacroID, enabled: Bool) {
        precondition(macroEnabled[id] != nil, "unknown macro \(id)")
        macroEnabled[id] = enabled
        updateHotKeys()
    }

    /// Runs a macro directly, like Keyboard Maestro's Execute Macro action.
    public func run(_ id: MacroID) {
        guard let macro = macro(id) else {
            log.error("macro \(id.value, privacy: .public) is not installed")
            return
        }
        macro.action(self)
    }

    // MARK: Matching

    /// Enabled macros whose group is enabled, activated and applies to this context.
    private func activeMacros(in context: FrontContext) -> [Macro] {
        macros.filter { macro in
            macroEnabled[macro.id] == true
                && groupEnabled[macro.group] == true
                && groupActivated[macro.group] == true
                && groups[macro.group]?.applies(to: context) == true
        }
    }

    /// Macros that would fire for this key in this context, best match first.
    public func candidates(for combo: KeyCombo, phase: KeyPhase, in context: FrontContext) -> [Macro] {
        activeMacros(in: context)
            .filter { macro in macro.hotKeys.contains { $0.combo == combo && $0.phase == phase } }
            .sorted { (groups[$0.group]?.specificity ?? 0) > (groups[$1.group]?.specificity ?? 0) }
    }

    public func activeCombos(in context: FrontContext) -> Set<KeyCombo> {
        Set(activeMacros(in: context).flatMap { $0.hotKeys.map(\.combo) })
    }

    private func updateHotKeys() {
        guard started else { return }
        HotKeyCenter.shared.setActive(isEnabled ? activeCombos(in: context) : [])
    }

    private func handle(_ combo: KeyCombo, _ event: HotKeyEvent) {
        // The window may have changed since the keys were registered, so check again.
        context = ContextMonitor.shared.refresh()
        let phase: KeyPhase = event == .released ? .released : .pressed
        guard isEnabled, let macro = candidates(for: combo, phase: phase, in: context).first else {
            if phase == .pressed && candidates(for: combo, phase: .released, in: context).isEmpty {
                log.notice("no macro for \(combo.description, privacy: .public), passing it on")
                HotKeyCenter.shared.passThrough(combo)
            }
            updateHotKeys()
            return
        }
        log.notice("\(combo.description, privacy: .public) -> \(macro.id.value, privacy: .public)")
        macro.action(self)
    }
}
