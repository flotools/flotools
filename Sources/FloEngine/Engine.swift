import FloSystem
import Foundation

/// A reason Flo Tools pauses by itself, apart from the user's on/off switch, for example while VoiceOver is not running. The reasons are declared by the macros that set them.
public struct Suspension: Hashable, Sendable, CustomStringConvertible {
    /// Says why, for the status menu and the log, for example "VoiceOver is not running".
    public let reason: String

    public init(_ reason: String) {
        self.reason = reason
    }

    public var description: String { reason }
}

/// Connects hotkeys to installed macros, honoring each macro's scope (front window) and mode condition, and runs the macros.
/// Only installed macros take keys, so other keys stay free.
///
/// All state is owned by the main actor; macro bodies run off it (see `MacroBody`). Top-level runs go through one serial queue, so two macros never interleave across an `await`; nested runs execute inside their parent. Holds (`MacroAction.hold`) bypass the queue.
@MainActor
public final class MacroEngine {
    /// Watches that macros start and stop, such as the level meter monitor. Stopped with the engine.
    public let monitors = Monitors()
    public private(set) var macros: [Macro] = []
    public var isEnabled = true {
        didSet {
            Log.info(.engine, isEnabled ? "Flo Tools enabled" : "Flo Tools disabled")
            stateChanged(voidsPendingSingles: true)
        }
    }

    /// Why Flo Tools is paused by itself. While any reason holds, no hotkey is taken, as while `isEnabled` is false; the two are kept apart so a suspension ending never turns on a Flo Tools the user turned off.
    public private(set) var suspensions: Set<Suspension> = []

    /// Called after each change of the front app or window, once the engine has updated its hotkeys.
    public var onContextChange: ((FrontContext) -> Void)?

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

    /// App state that decides which keys apply, such as whether the Inspector is on. Starts with the Inspector off.
    public private(set) var mode = Mode()

    private let hotKeys: HotKeyCenter
    private let contextMonitor: ContextMonitor
    private var macroIndex: [MacroID: Int] = [:]
    /// Macros by hotkey, so a key press does not scan every macro.
    private var macrosByCombo: [KeyCombo: [MacroID]] = [:]
    private var macroEnabled: [MacroID: Bool] = [:]
    private var started = false
    /// True while `updateHotKeys` ends holds, so a release that changes state does not update the hotkeys from inside the update.
    private var endingHolds = false

    private var doublePress = DoublePressDecider(timeout: .milliseconds(200))
    private var pendingSingles: [MacroID: Task<Void, Never>] = [:]
    /// The last queued top-level run; the next one waits for it.
    private var queueTail: Task<Void, Never>?
    /// Queued and running top-level runs, so `stop` can cancel them. Keyed by queue position, not run number, because a delayed single press joins the queue after later runs.
    private var runs: [Int: Task<Void, Never>] = [:]
    private var queuedCount = 0
    /// Numbers macro runs for the log's invocation IDs.
    private var runCount = 0
    /// Keys whose hold has started and not ended, with the run that started it and its invocation ID.
    private var holds: [KeyCombo: (run: MacroRun, release: HoldRelease, invocation: String)] = [:]

    public init(hotKeys: HotKeyCenter, contextMonitor: ContextMonitor) {
        self.hotKeys = hotKeys
        self.contextMonitor = contextMonitor
    }

    // MARK: Setup

    /// Adds a macro. Stops the app if its ID is taken or one of its keys ties with an installed macro's; the tests install every macro, so they catch both first.
    public func install(_ macro: Macro) {
        precondition(macroIndex[macro.id] == nil, "macro \(macro.id) installed twice")
        if let tie = tie(with: macro) { preconditionFailure(tie) }
        macroIndex[macro.id] = macros.count
        macros.append(macro)
        macroEnabled[macro.id] = macro.enabledByDefault
        for combo in Set(macro.hotKeys.map(\.combo)) { macrosByCombo[combo, default: []].append(macro.id) }
        updateHotKeys()
    }

    public func macro(_ id: MacroID) -> Macro? { macroIndex[id].map { macros[$0] } }

    /// Why `macro` cannot be installed beside the installed macros, or nil. Two macros tie when one key and phase could start both in the same window and mode with the same precedence, so neither would be the clear choice. A preference that turns one off does not count: both can be on.
    func tie(with macro: Macro) -> String? {
        for (combo, phase) in macro.hotKeys {
            for other in (macrosByCombo[combo] ?? []).compactMap(self.macro) where other.id != macro.id
                && other.hotKeys.contains(where: { $0 == (combo, phase) })
                && other.scope.precedence == macro.scope.precedence
                && other.scope.overlaps(macro.scope)
                && other.mode.overlaps(macro.mode) {
                return "\(combo) \(phase) is bound by both \(other.id) and \(macro.id) in the same windows and mode"
            }
        }
        return nil
    }

    public func start() {
        guard !started else { return }
        started = true
        hotKeys.handler = { [weak self] combo, phase in self?.handle(combo, phase) }
        contextMonitor.onChange = { [weak self] context in
            Log.info(.context, "front: \(context)")
            self?.context = context
            // A single press waiting for its timeout belongs to the window it was pressed in.
            self?.stateChanged(voidsPendingSingles: true)
            self?.onContextChange?(context)
        }
        contextMonitor.start()
        context = contextMonitor.current
        updateHotKeys()
    }

    /// Cancels pending, queued and running macros and releases the hotkeys and observers.
    public func stop() {
        cancelAll()
        guard started else { return }
        started = false
        hotKeys.stop()
        contextMonitor.stop()
    }

    /// Cancels pending, queued and running macros, ends holds and stops watches, but keeps the hotkeys and observers. Like Keyboard Maestro's Cancel All Macros, used when Pro Tools quits.
    /// Cancelling only asks the work to stop, and a run may still write remembered state before it notices. The returned task ends once every cancelled run and watch has ended, so a caller that resets such state waits for it first.
    @discardableResult
    public func cancelAll() -> Task<Void, Never> {
        Log.info(.engine, "cancelling all macros")
        endHolds { _ in true }
        cancelPendingSingles()
        let cancelledRuns = Array(runs.values)
        cancelledRuns.forEach { $0.cancel() }
        let watchesEnded = monitors.stopAll()
        return Task { @MainActor in
            for run in cancelledRuns { await run.value }
            await watchesEnded.value
        }
    }

    /// Reads the front app and window again, for example after Accessibility access was granted.
    public func refreshContext() {
        contextMonitor.refresh()
    }

    // MARK: State

    public func suspend(_ suspension: Suspension) {
        guard suspensions.insert(suspension).inserted else { return }
        Log.info(.engine, "suspended: \(suspension)")
        stateChanged(voidsPendingSingles: true)
    }

    public func resume(_ suspension: Suspension) {
        guard suspensions.remove(suspension) != nil else { return }
        Log.info(.engine, "resumed: \(suspension)")
        stateChanged(voidsPendingSingles: true)
    }

    /// Whether hotkeys work at all: Flo Tools is on and nothing suspends it.
    private var takesKeys: Bool { isEnabled && suspensions.isEmpty }

    /// Turns the Inspector on or off. A mode change does not void pending single presses: a single press of S accepted while the temporary Inspector key was held must still speak after the release.
    public func setInspector(_ on: Bool) {
        guard mode.inspector != on else { return }
        mode.inspector = on
        Log.info(.engine, on ? "Inspector on" : "Inspector off")
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
        macroEnabled[macro.id] == true && macro.scope.applies(to: context) && macro.mode.holds(in: mode)
    }

    /// Macros that would fire for this key in this context, best match first. `tie(with:)` keeps two from having the same precedence.
    public func candidates(for combo: KeyCombo, phase: KeyPhase, in context: FrontContext) -> [Macro] {
        (macrosByCombo[combo] ?? [])
            .compactMap(macro)
            .filter { macro in isActive(macro, in: context) && macro.hotKeys.contains { $0.combo == combo && $0.phase == phase } }
            .sorted { $0.scope.precedence > $1.scope.precedence }
    }

    /// The macros that offer themselves in the status menu now, like Keyboard Maestro's status menu, which listed the macros of the groups active for the front window: those whose scope and mode apply now.
    public func statusMenuMacros(in context: FrontContext) -> [Macro] {
        guard takesKeys else { return [] }
        return macros.filter { macro in macro.triggers.contains(.statusMenu) && isActive(macro, in: context) }
    }

    public func activeCombos(in context: FrontContext) -> Set<KeyCombo> {
        Set(macrosByCombo.filter { _, ids in ids.contains { id in macro(id).map { isActive($0, in: context) } ?? false } }.keys)
    }

    private func updateHotKeys() {
        guard started, !endingHolds else { return }
        var combos = takesKeys ? activeCombos(in: context) : []
        // A held key that is no longer a hotkey would never report its release, so its hold ends now. A release can change state, for example deactivate the Inspector, so the keys are worked out again after it. Ends because every pass removes a hold.
        while holds.keys.contains(where: { !combos.contains($0) }) {
            endingHolds = true
            endHolds { !combos.contains($0) }
            endingHolds = false
            combos = takesKeys ? activeCombos(in: context) : []
        }
        hotKeys.setActive(combos)
    }

    // MARK: Running

    private func handle(_ combo: KeyCombo, _ phase: KeyPhase) {
        // Route on the cached context: reading the window here would block every key while Pro Tools is busy. Only a change of front app, which needs no Accessibility call to notice, is checked first.
        context = contextMonitor.refreshIfFrontAppChanged()
        if dispatch(combo, phase, in: context) == nil {
            if phase == .pressed && candidates(for: combo, phase: .released, in: context).isEmpty {
                // The key is not named: keys no macro matched must not appear in the log.
                Log.info(.engine, "no macro for this key in \(context), passing it on")
                passThrough(combo, to: context)
            }
            updateHotKeys()
        }
    }

    /// Starts the best macro for this key in this context, which becomes the engine's current one: queued runs are checked against it. Returns the run's invocation ID, or nil when no macro takes the key.
    @discardableResult
    func dispatch(_ combo: KeyCombo, _ phase: KeyPhase, in context: FrontContext) -> String? {
        self.context = context
        if phase == .released, let hold = holds[combo] {
            endHolds { $0 == combo }
            return hold.invocation
        }
        guard takesKeys, let macro = candidates(for: combo, phase: phase, in: context).first else { return nil }
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

    /// Runs a macro because `event` happened, if it could run from a hotkey now: Flo Tools is on and not suspended, and the macro is on and its scope and mode apply. Checked again when the run reaches the front of the queue, like a hotkey run.
    public func fire(_ id: MacroID, on event: String) {
        guard let macro = macro(id) else {
            Log.error(.engine, "macro \(id) is not installed")
            return
        }
        guard takesKeys, isActive(macro, in: context) else {
            Log.info(.engine, "\(event): \(id) is not active in \(context)")
            return
        }
        _ = start(macro, trigger: .event(event), context: context, reason: event)
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
            case .hold(let press, let release):
                // Only a press starts a hold; a release reaching here belongs to a press that did not.
                guard case .hotKey(let combo, .pressed) = trigger else { return }
                if press(run) { holds[combo] = (run, release, invocation) }
            case .singleOrDouble(let single, let double, let doneSound):
                switch doublePress.press(macro.id, at: .now) {
                case .double:
                    pendingSingles.removeValue(forKey: macro.id)?.cancel()
                    Log.info(.engine, "double press")
                    enqueue(run, Self.withDoneSound(double, doneSound))
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

    private static func withDoneSound(_ double: @escaping MacroBody, _ doneSound: DoneSoundTiming) -> MacroBody {
        switch doneSound {
        case .beforeDouble:
            return { run in
                await Sound.done.play()
                try await double(run)
            }
        case .afterDouble:
            return { run in
                try await double(run)
                await Sound.done.play()
            }
        case .none:
            return double
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
            if let reason = self?.invalidReason(run) {
                Log.info(.engine, "\(run.macro.id) dropped: \(reason)")
                self?.runs[number] = nil
                return
            }
            do {
                try Task.checkCancellation()
                try await body(run)
                Log.info(.engine, "\(run.macro.id) finished (\(Log.elapsed(since: start)))")
            } catch is CancellationError {
                Log.info(.engine, "\(run.macro.id) cancelled (\(Log.elapsed(since: start)))")
            } catch {
                Log.error(.engine, "\(run.macro.id) failed: \(error) (\(Log.elapsed(since: start)))")
                if let text = SpokenError.text(for: error) { VoiceOver.sayOrLog(text) }
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
        case .hold:
            Log.warning(.engine, "\(macro.id) holds a key and cannot be run by another macro")
        }
    }

    /// Why a queued hotkey or event run must not start any more, or nil if it may. Checked when it reaches the front of the queue, because Flo Tools, the macro or the front app may have changed while it waited. Of the mode, only the Inspector turning on is checked, because the keys of an Inspector-off macro (track view) now pan. An Inspector-on macro is not dropped when the Inspector turns off: a single press of S accepted while the temporary Inspector key was held must still speak after the release.
    private func invalidReason(_ run: MacroRun) -> String? {
        switch run.trigger {
        case .hotKey, .event: break
        case .nested, .direct: return nil
        }
        if !isEnabled { return "Flo Tools is disabled" }
        if let suspension = suspensions.first { return "suspended: \(suspension)" }
        if macroEnabled[run.macro.id] != true { return "macro disabled" }
        if context.processID != run.context.processID { return "another app is in front" }
        if !run.macro.scope.applies(to: context) { return "not in its windows: \(context)" }
        if run.macro.mode == .inspectorOff && mode.inspector { return "the Inspector is on" }
        return nil
    }

    /// Ends the holds whose key matches, running their release with the current context.
    private func endHolds(where ends: (KeyCombo) -> Bool) {
        for combo in holds.keys.filter(ends) {
            guard let hold = holds.removeValue(forKey: combo) else { continue }
            Log.$invocation.withValue(hold.invocation) {
                Log.info(.engine, "\(hold.run.macro.id) hold of \(combo) ended")
                let release = MacroRun(macro: hold.run.macro, trigger: .hotKey(combo, .released), context: context, engine: self, path: hold.run.path)
                hold.release(release)
            }
        }
    }

    /// Waits until pending single presses have run and the queue is empty. Lets tests check results without guessing durations.
    func waitUntilIdle() async {
        for single in Array(pendingSingles.values) { await single.value }
        while let tail = queueTail, runs.isEmpty == false { await tail.value }
    }

    /// Sends a key Carbon took from the front app on to it. Posted to the process, so the key is not caught as a hotkey again.
    func passThrough(_ combo: KeyCombo, to context: FrontContext) {
        guard context.processID > 0 else {
            Log.warning(.engine, "no front app to pass a key on to, the key is lost")
            return
        }
        Keyboard.post(combo, pid: context.processID)
    }

    private func cancelPendingSingles() {
        doublePress.cancelAll()
        pendingSingles.values.forEach { $0.cancel() }
        pendingSingles = [:]
    }
}
