import FloSystem
import Foundation

/// Connects hotkeys to installed macros, honoring group app and window conditions like Keyboard Maestro, and runs the macros.
/// Only installed macros take keys, so other keys stay free.
///
/// All state is owned by the main actor. Top-level runs go through one serial queue, so two macros never interleave across an `await`; nested runs execute inside their parent.
@MainActor
public final class MacroEngine {
    public let groups: [MacroGroupID: MacroGroup]
    public private(set) var macros: [Macro] = []
    public var isEnabled = true {
        didSet {
            Log.info(.engine, isEnabled ? "Flo Tools enabled" : "Flo Tools disabled")
            stateChanged(voidsPendingSingles: true)
        }
    }

    /// The double-press window, from the "timeout" preference. Changing it voids pending single presses.
    public var doublePressTimeout: Duration {
        get { doublePress.timeout }
        set {
            doublePress.timeout = newValue
            cancelPendingSingles()
        }
    }

    /// The front app and window, refreshed before each hotkey runs its macro.
    public private(set) var context = FrontContext()

    private let hotKeys: HotKeyCenter
    private let contextMonitor: ContextMonitor
    private var macroIndex: [MacroID: Int] = [:]
    /// Macros by hotkey, so a key press does not scan every macro.
    private var macrosByCombo: [KeyCombo: [MacroID]] = [:]
    private var groupEnabled: [MacroGroupID: Bool]
    private var groupActivated: [MacroGroupID: Bool]
    private var macroEnabled: [MacroID: Bool] = [:]
    private var started = false
    /// Above zero while `batch` runs, so several state changes update the hotkeys once.
    private var batchDepth = 0

    private var doublePress = DoublePressDecider(timeout: .milliseconds(200))
    private var pendingSingles: [MacroID: Task<Void, Never>] = [:]
    /// The last queued top-level run; the next one waits for it.
    private var queueTail: Task<Void, Never>?
    /// Queued and running top-level runs, so `stop` can cancel them. Keyed by queue position, not run number, because a delayed single press joins the queue after later runs.
    private var runs: [Int: Task<Void, Never>] = [:]
    private var queuedCount = 0
    /// Numbers macro runs for the log's invocation IDs.
    private var runCount = 0

    public init(groups: [MacroGroup], hotKeys: HotKeyCenter, contextMonitor: ContextMonitor) {
        self.groups = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })
        groupEnabled = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0.enabledByDefault) })
        groupActivated = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, true) })
        self.hotKeys = hotKeys
        self.contextMonitor = contextMonitor
    }

    // MARK: Setup

    public func install(_ macro: Macro) {
        precondition(groups[macro.group] != nil, "macro \(macro.id) has unknown group \(macro.group)")
        precondition(macroIndex[macro.id] == nil, "macro \(macro.id) installed twice")
        macroIndex[macro.id] = macros.count
        macros.append(macro)
        macroEnabled[macro.id] = macro.enabledByDefault
        for combo in Set(macro.hotKeys.map(\.combo)) { macrosByCombo[combo, default: []].append(macro.id) }
        updateHotKeys()
    }

    public func macro(_ id: MacroID) -> Macro? { macroIndex[id].map { macros[$0] } }

    public func start() {
        guard !started else { return }
        started = true
        hotKeys.handler = { [weak self] combo, event in self?.handle(combo, event) }
        contextMonitor.onChange = { [weak self] context in
            Log.info(.context, "front: \(context)")
            self?.context = context
            // A single press waiting for its timeout belongs to the window it was pressed in.
            self?.stateChanged(voidsPendingSingles: true)
        }
        contextMonitor.start()
        context = contextMonitor.current
        updateHotKeys()
    }

    /// Cancels pending, queued and running macros and releases the hotkeys and observers.
    public func stop() {
        cancelPendingSingles()
        runs.values.forEach { $0.cancel() }
        guard started else { return }
        started = false
        hotKeys.stop()
        contextMonitor.stop()
    }

    /// Reads the front app and window again, for example after Accessibility access was granted.
    public func refreshContext() {
        contextMonitor.refresh()
    }

    // MARK: State, like Keyboard Maestro's group and macro enable actions

    /// Makes several state changes with one hotkey update at the end, for example when Toggle Inspector switches a group and two macros.
    public func batch(_ changes: () -> Void) {
        batchDepth += 1
        changes()
        batchDepth -= 1
        updateHotKeys()
    }

    public func isGroupEnabled(_ id: MacroGroupID) -> Bool { groupEnabled[id] ?? false }

    public func setGroup(_ id: MacroGroupID, enabled: Bool) {
        precondition(groups[id] != nil, "unknown group \(id)")
        groupEnabled[id] = enabled
        Log.info(.engine, "group \(id) \(enabled ? "enabled" : "disabled")")
        stateChanged(voidsPendingSingles: true)
    }

    /// Whether the group is activated, like Keyboard Maestro's Activate/Deactivate Macro Group action. This is separate from enabled: Toggle Inspector activates and deactivates the Inspector group, while Flo Tools' own on/off switch enables and disables groups. Groups start activated.
    public func isGroupActivated(_ id: MacroGroupID) -> Bool { groupActivated[id] ?? false }

    /// Activation does not void pending single presses: releasing the temporary Inspector key within the double-press timeout must still let a single press of S speak.
    public func setGroup(_ id: MacroGroupID, activated: Bool) {
        precondition(groups[id] != nil, "unknown group \(id)")
        groupActivated[id] = activated
        Log.info(.engine, "group \(id) \(activated ? "activated" : "deactivated")")
        stateChanged(voidsPendingSingles: false)
    }

    public func isMacroEnabled(_ id: MacroID) -> Bool { macroEnabled[id] ?? false }

    public func setMacro(_ id: MacroID, enabled: Bool) {
        precondition(macroEnabled[id] != nil, "unknown macro \(id)")
        macroEnabled[id] = enabled
        Log.info(.engine, "macro \(id) \(enabled ? "enabled" : "disabled")")
        stateChanged(voidsPendingSingles: true)
    }

    private func stateChanged(voidsPendingSingles: Bool) {
        if voidsPendingSingles { cancelPendingSingles() }
        updateHotKeys()
    }

    // MARK: Matching

    private func isActive(_ macro: Macro, in context: FrontContext) -> Bool {
        macroEnabled[macro.id] == true
            && groupEnabled[macro.group] == true
            && groupActivated[macro.group] == true
            && groups[macro.group]?.applies(to: context) == true
    }

    /// Macros that would fire for this key in this context, best match first.
    public func candidates(for combo: KeyCombo, phase: KeyPhase, in context: FrontContext) -> [Macro] {
        (macrosByCombo[combo] ?? [])
            .compactMap(macro)
            .filter { macro in isActive(macro, in: context) && macro.hotKeys.contains { $0.combo == combo && $0.phase == phase } }
            .sorted { (groups[$0.group]?.specificity ?? 0) > (groups[$1.group]?.specificity ?? 0) }
    }

    public func activeCombos(in context: FrontContext) -> Set<KeyCombo> {
        Set(macrosByCombo.filter { _, ids in ids.contains { id in macro(id).map { isActive($0, in: context) } ?? false } }.keys)
    }

    private func updateHotKeys() {
        guard started, batchDepth == 0 else { return }
        hotKeys.setActive(isEnabled ? activeCombos(in: context) : [])
    }

    // MARK: Running

    private func handle(_ combo: KeyCombo, _ event: HotKeyEvent) {
        // The window may have changed since the keys were registered, so check again.
        context = contextMonitor.refresh()
        let phase: KeyPhase = event == .released ? .released : .pressed
        if dispatch(combo, phase, in: context) == nil {
            if phase == .pressed && candidates(for: combo, phase: .released, in: context).isEmpty {
                // The key is not named: keys no macro matched must not appear in the log.
                Log.info(.engine, "no macro for this key in \(context), passing it on")
                hotKeys.passThrough(combo)
            }
            updateHotKeys()
        }
    }

    /// Starts the best macro for this key in this context. Returns the run's invocation ID, or nil when no macro takes the key.
    @discardableResult
    func dispatch(_ combo: KeyCombo, _ phase: KeyPhase, in context: FrontContext) -> String? {
        guard isEnabled, let macro = candidates(for: combo, phase: phase, in: context).first else { return nil }
        return start(macro, trigger: .hotKey(combo, phase), context: context, reason: "\(combo) \(phase) in \(context)")
    }

    /// Runs a macro from the app, for example a status menu item. Errors are spoken like those of hotkey runs.
    public func run(_ id: MacroID) {
        guard let macro = macro(id) else {
            Log.error(.engine, "macro \(id) is not installed")
            return
        }
        _ = start(macro, trigger: .direct, context: context, reason: "run by the app")
    }

    /// Gives the run an invocation ID and starts it, waiting first for a double press where the macro has one.
    private func start(_ macro: Macro, trigger: MacroRun.Trigger, context: FrontContext, reason: String) -> String {
        runCount += 1
        let invocation = "run\(runCount)"
        // Tasks created in this scope inherit the invocation ID, so delayed single presses carry it too.
        Log.$invocation.withValue(invocation) {
            Log.info(.engine, "\(reason) -> \(macro.id) \"\(macro.name)\"")
            let run = MacroRun(macro: macro, trigger: trigger, context: context, engine: self, path: [macro.id])
            switch macro.action {
            case .body(let body):
                enqueue(run, body)
            case .singleOrDouble(let single, let double, let tink):
                switch doublePress.press(macro.id, at: .now) {
                case .double:
                    pendingSingles.removeValue(forKey: macro.id)?.cancel()
                    Log.info(.engine, "double press")
                    enqueue(run, Self.withTink(double, tink))
                case .single(let generation):
                    let wait = doublePress.timeout
                    pendingSingles[macro.id] = Task { @MainActor [weak self] in
                        try? await Task.sleep(for: wait)
                        guard let self, !Task.isCancelled, self.doublePress.singleIsDue(macro.id, generation: generation) else { return }
                        self.pendingSingles[macro.id] = nil
                        Log.info(.engine, "single press")
                        self.enqueue(run, single)
                    }
                }
            }
        }
        return invocation
    }

    private static func withTink(_ double: @escaping MacroBody, _ tink: TinkTiming) -> MacroBody {
        switch tink {
        case .beforeDouble:
            return { run in
                Sound.play("Tink")
                try await double(run)
            }
        case .afterDouble:
            return { run in
                try await double(run)
                Sound.play("Tink")
            }
        }
    }

    /// Adds a top-level run to the serial queue. Its errors end here: logged, and spoken through `SpokenError`.
    private func enqueue(_ run: MacroRun, _ body: @escaping MacroBody) {
        queuedCount += 1
        let number = queuedCount
        let previous = queueTail
        let task = Task { @MainActor [weak self] in
            await previous?.value
            let start = ContinuousClock.now
            do {
                try Task.checkCancellation()
                try await body(run)
                Log.info(.engine, "\(run.macro.id) finished (\(Log.elapsed(since: start)))")
            } catch is CancellationError {
                Log.info(.engine, "\(run.macro.id) cancelled (\(Log.elapsed(since: start)))")
            } catch {
                Log.error(.engine, "\(run.macro.id) failed: \(error) (\(Log.elapsed(since: start)))")
                if let text = SpokenError.text(for: error) { VoiceOver.say(text) }
            }
            self?.runs[number] = nil
        }
        runs[number] = task
        queueTail = task
    }

    /// Runs a macro inside another, bypassing enable state and window conditions, as Keyboard Maestro's Execute Macro did. A double-press macro runs its single action.
    func runNested(_ id: MacroID, from parent: MacroRun) async throws {
        let macro = try macro(id).required("the macro \(id)")
        let path = parent.path + [id]
        guard !parent.path.contains(id) else {
            throw FloError.cycle(path: path.map(\.description).joined(separator: " -> "))
        }
        Log.info(.engine, "\(parent.macro.id) runs \(macro.id) \"\(macro.name)\"")
        let run = MacroRun(macro: macro, trigger: .nested(by: parent.macro.id), context: parent.context, engine: self, path: path)
        switch macro.action {
        case .body(let body), .singleOrDouble(let body, _, _):
            try await body(run)
        }
    }

    /// Waits until pending single presses have run and the queue is empty. Lets tests check results without guessing durations.
    func waitUntilIdle() async {
        for single in Array(pendingSingles.values) { await single.value }
        while let tail = queueTail, runs.isEmpty == false { await tail.value }
    }

    func passThrough(_ combo: KeyCombo) {
        hotKeys.passThrough(combo)
    }

    private func cancelPendingSingles() {
        doublePress.cancelAll()
        pendingSingles.values.forEach { $0.cancel() }
        pendingSingles = [:]
    }
}
