import FloProTools
import FloSystem
import Foundation

/// A reason Flo Tools pauses by itself, apart from the user's on/off switch, for example while VoiceOver is not running. The reasons are declared by the commands that set them.
public struct Suspension: Hashable, Sendable, CustomStringConvertible {
    /// Says why, for the status menu and the log, for example "VoiceOver is not running".
    public let reason: String

    public init(_ reason: String) {
        self.reason = reason
    }

    public var description: String { reason }
}

/// Connects hotkeys to installed commands, honoring each command's scope (front window, or the track under the VoiceOver cursor), and runs the commands.
/// Only installed commands take keys, so other keys stay free.
///
/// All state is owned by the main actor; command bodies run off it (see `CommandBody`). Key presses are admitted in order through one queue, and top-level runs go through one serial queue, so two commands never interleave across an `await`.
@MainActor
public final class Engine {
    /// Watches that commands start and stop, such as the level meter monitor. Stopped with the engine.
    public let watches = Watches()
    public private(set) var commands: [Command] = []
    public var isEnabled = true {
        didSet {
            Log.info(.engine, isEnabled ? "Flo Tools enabled" : "Flo Tools disabled")
            stateChanged()
        }
    }

    /// Why Flo Tools is paused by itself. While any reason holds, no hotkey is taken, as while `isEnabled` is false; the two are kept apart so a suspension ending never turns on a Flo Tools the user turned off.
    public private(set) var suspensions: Set<Suspension> = []

    /// Called after each change of the front app or window, once the engine has updated its hotkeys.
    public var onContextChange: ((FrontContext) -> Void)?

    /// How long a key with a tap and a hold action must stay down to count as held, from the preferences. Changing it voids pending taps. It starts at the preference default until the app applies the preferences.
    public var holdTime: Duration = .milliseconds(Preferences().holdTime) {
        didSet {
            guard oldValue != holdTime else { return }
            voidPendingInput()
        }
    }

    /// The front app and window that keys are routed on, kept current by the context monitor. A key press refreshes only the front app, because reading the window could block while Pro Tools is busy.
    public private(set) var context = FrontContext()

    /// Read at each press of a repeating command, so a change in System Settings applies at once, and for whether a key is still held. Tests set their own.
    var keyRepeat: @MainActor () -> KeyRepeat = { .system }

    // What a press needs outside the engine: the track under the VoiceOver cursor, for a command scoped to it, and sending a key on to an app. Tests replace both.
    var detectInspectorTarget: @Sendable (FrontContext) async throws -> InspectorTarget? = { context in
        let window: ProToolsApp.TrackWindow = context.proToolsWindowKind == .mix ? .mix : .edit
        return try await ProToolsApp(pid: context.processID).inspectorTargetUnderVoiceOverCursor(in: window)
    }
    var postKey: @MainActor (KeyCombo, FrontContext) -> Void = { combo, context in
        Keyboard.post(combo, pid: context.processID)
    }
    /// What takes the keys of the app in `context`, if anything. The VoiceOver cursor still reports the track behind a menu Pro Tools opened from it and behind a counter opened for typing (checked live 2026-11-07), so the cursor check alone would accept it. Throws when that cannot be told.
    var keyCapture: @MainActor (FrontContext) async throws -> KeyCapture?
    /// A key press whose release, which is not queued, must reach code still waiting on it: the admission queue, the hold decision and repeating.
    @MainActor private final class Press {
        var released = false {
            didSet { if released { nap?.cancel() } }
        }
        /// The hold decision's current sleep, cut short by the release so a tap runs at once.
        var nap: Task<Void, Never>?
    }

    /// How a run's start relates to the presses before it.
    private enum Ordering {
        /// Started as it came, from the app or on an event.
        case immediate
        /// A key press admitted through the queue. `generation` voids it when what it was admitted under changes; `press` tells whether the key was let go while it waited.
        case admitted(generation: Int, press: Press)
    }

    /// One press, app request or event on its way to a command, with what the engine knows about it. Made once, in `newInvocation`.
    private struct Invocation {
        /// The log's invocation ID, for example "run12".
        let id: String
        /// When the key went down, which holds are timed from, even when admission makes the run start later.
        let arrival: ContinuousClock.Instant
        let ordering: Ordering
        /// The track under the VoiceOver cursor when the press was admitted, for a command scoped to it; nil for any other run.
        var target: InspectorTarget? = nil

        var press: Press? {
            if case .admitted(_, let press) = ordering { press } else { nil }
        }
        var generation: Int? {
            if case .admitted(let generation, _) = ordering { generation } else { nil }
        }
    }

    /// A press of a key with a tap and a hold action, waiting to tell which. Kept with its tap action, so a new press of the key can run it at once.
    private struct PendingTap {
        let task: Task<Void, Never>
        let run: CommandRun
        let body: CommandBody
        let invocation: Invocation
    }

    private var presses: [KeyCombo: Press] = [:]
    private var inputGeneration = 0
    private var admissionTail: Task<Void, Never>?
    private var admissions = 0

    /// Voids every press not yet run: admissions still deciding, taps waiting to tell a tap from a hold, and repeating started on a track under the cursor. Called when what a press was accepted under changes.
    private func voidPendingInput() {
        inputGeneration += 1
        presses.values.forEach { $0.released = true }
        presses = [:]
        endTrackHolds()
        pendingTaps.values.forEach { $0.task.cancel() }
        pendingTaps = [:]
    }

    private func inputIsValid(_ generation: Int, _ original: FrontContext) -> Bool {
        generation == inputGeneration && takesKeys && context == original
    }

    /// Queues the press behind earlier ones, so a later press, even of a key that needs no check, never runs before an earlier press's cursor check ends. Releases are not queued.
    private func admit(_ combo: KeyCombo, in original: FrontContext, at arrival: ContinuousClock.Instant) -> String {
        let generation = inputGeneration
        let press = trackRelease(of: combo)
        let input = newInvocation(at: arrival, .admitted(generation: generation, press: press))
        let previous = admissionTail
        admissions += 1
        admissionTail = Task { @MainActor [weak self] in
            await previous?.value
            guard let self else { return }
            defer { self.admissions -= 1 }
            await Log.$invocation.withValue(input.id) {
                guard self.inputIsValid(generation, original) else {
                    Log.info(.engine, "input dropped: stale admission")
                    return
                }
                let candidates = self.candidates(for: combo, in: original)
                guard let best = candidates.first else {
                    self.passThrough(combo, to: original)
                    return
                }
                guard best.scope == .trackUnderVoiceOverCursor else {
                    _ = self.start(best, hotKey: combo, in: original, invocation: input)
                    return
                }
                Log.info(.engine, "checking the VoiceOver cursor in \(original)")
                let target: InspectorTarget?
                do {
                    target = try await self.detectInspectorTarget(original)
                } catch {
                    Log.error(.engine, "could not check the track under the VoiceOver cursor: \(error)")
                    target = nil
                }
                guard self.inputIsValid(generation, original) else {
                    Log.info(.engine, "input dropped: stale cursor check")
                    return
                }
                // Checked after the cursor, the latest moment before deciding, so a menu or field that opened meanwhile still counts. When it cannot be told, the key goes to Pro Tools, which is right if a field is open and harmless if not.
                let capture: KeyCapture?
                var captureFailed = false
                do {
                    capture = try await self.keyCapture(original)
                } catch {
                    Log.error(.engine, "could not check for an open menu or text field: \(error)")
                    capture = nil
                    captureFailed = true
                }
                guard self.inputIsValid(generation, original) else {
                    Log.info(.engine, "input dropped: stale key capture check")
                    return
                }
                guard capture == nil, !captureFailed else {
                    Log.info(.engine, capture.map { "passing the key on: \($0)" } ?? "passing the key on")
                    self.passThrough(combo, to: original)
                    return
                }
                guard let target, target.processID == original.processID else {
                    // Off a track, the key does what it does without the cursor check, for example Ctrl+Cmd+Right announces the next track view.
                    if let next = candidates.first(where: { $0.scope != .trackUnderVoiceOverCursor }) {
                        Log.info(.engine, "no track under the VoiceOver cursor")
                        _ = self.start(next, hotKey: combo, in: original, invocation: input)
                    } else {
                        Log.info(.engine, "no track under the VoiceOver cursor, passing the key on")
                        self.passThrough(combo, to: original)
                    }
                    return
                }
                Log.info(.engine, "track under the VoiceOver cursor: \(target.name)")
                var accepted = input
                accepted.target = target
                _ = self.start(best, hotKey: combo, in: original, invocation: accepted)
            }
        }
        return input.id
    }

    /// Numbers a run for the log and records when its key went down. The one place invocation IDs are made.
    private func newInvocation(at arrival: ContinuousClock.Instant, _ ordering: Ordering) -> Invocation {
        runCount += 1
        return Invocation(id: "run\(runCount)", arrival: arrival, ordering: ordering)
    }

    /// Runs the pending tap of command `id` now, rather than when its key's release is noticed.
    private func flushTap(_ id: CommandID) {
        guard let pending = pendingTaps.removeValue(forKey: id) else { return }
        pending.task.cancel()
        Log.$invocation.withValue(pending.invocation.id) { enqueue(pending.run, pending.body) }
    }

    private let hotKeys: HotKeyCenter
    private let contextMonitor: ContextMonitor
    private var commandIndex: [CommandID: Int] = [:]
    /// Commands by hotkey, so a key press does not scan every command.
    private var commandsByCombo: [KeyCombo: [CommandID]] = [:]
    private var commandEnabled: [CommandID: Bool] = [:]
    private var started = false

    private var pendingTaps: [CommandID: PendingTap] = [:]
    /// The last queued top-level run; the next one waits for it.
    private var queueTail: Task<Bool, Never>?
    /// Queued and running top-level runs, so `stop` can cancel them. Keyed by queue position, not run number, because a tap joins the queue only once its key is let go, after later runs.
    private var runs: [Int: Task<Bool, Never>] = [:]
    private var queuedCount = 0
    /// Numbers command runs for the log's invocation IDs.
    private var runCount = 0
    /// A key whose repeating has started and not ended: the run that started it, how to end it, and its invocation ID.
    private struct Hold {
        let run: CommandRun
        let end: @MainActor () -> Void
        let invocation: String
    }

    private var holds: [KeyCombo: Hold] = [:]

    public init(hotKeys: HotKeyCenter, contextMonitor: ContextMonitor) {
        self.hotKeys = hotKeys
        self.contextMonitor = contextMonitor
        keyCapture = { context in try await contextMonitor.keyCapture.check(pid: context.processID) }
    }

    // MARK: Setup

    /// Adds a command. Stops the app if its ID is taken or one of its keys ties with an installed command's; the tests install every command, so they catch both first.
    public func install(_ command: Command) {
        precondition(commandIndex[command.id] == nil, "command \(command.id) installed twice")
        if let tie = tie(with: command) { preconditionFailure(tie) }
        commandIndex[command.id] = commands.count
        commands.append(command)
        commandEnabled[command.id] = true
        for combo in Set(command.hotKeys) { commandsByCombo[combo, default: []].append(command.id) }
        updateHotKeys()
    }

    public func command(_ id: CommandID) -> Command? { commandIndex[id].map { commands[$0] } }

    /// Why `command` cannot be installed beside the installed commands, or nil. Two commands tie when one key could start both in the same window with the same precedence, so neither would be the clear choice.
    func tie(with command: Command) -> String? {
        for combo in command.hotKeys {
            for other in (commandsByCombo[combo] ?? []).compactMap(self.command) where other.id != command.id
                && other.hotKeys.contains(combo)
                && other.scope.precedence == command.scope.precedence
                && other.scope.overlaps(command.scope) {
                return "\(combo) is bound by both \(other.id) and \(command.id) in the same windows"
            }
        }
        return nil
    }

    public func start() {
        guard !started else { return }
        started = true
        hotKeys.handler = { [weak self] combo, phase in self?.handle(combo, phase) }
        contextMonitor.onChange = { [weak self] context in self?.contextChanged(to: context) }
        contextMonitor.start()
        context = contextMonitor.current
        updateHotKeys()
    }

    /// Cancels pending, queued and running commands and releases the hotkeys and observers.
    public func stop() {
        cancelAll()
        guard started else { return }
        started = false
        hotKeys.stop()
        contextMonitor.stop()
    }

    /// Cancels pending, queued and running commands, ends repeating and stops watches, but keeps the hotkeys and observers. Like Keyboard Maestro's Cancel All Macros, used when Pro Tools quits.
    /// Cancelling only asks the work to stop, and a run may still write remembered state before it notices. The returned task ends once every cancelled run and watch has ended, so a caller that resets such state waits for it first.
    @discardableResult
    public func cancelAll() -> Task<Void, Never> {
        Log.info(.engine, "cancelling all commands")
        endHolds { _ in true }
        voidPendingInput()
        let cancelledRuns = Array(runs.values)
        cancelledRuns.forEach { $0.cancel() }
        let watchesEnded = watches.stopAll()
        return Task { @MainActor in
            for run in cancelledRuns { _ = await run.value }
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
        stateChanged()
    }

    public func resume(_ suspension: Suspension) {
        guard suspensions.remove(suspension) != nil else { return }
        Log.info(.engine, "resumed: \(suspension)")
        stateChanged()
    }

    /// Whether hotkeys work at all: Flo Tools is on and nothing suspends it.
    private var takesKeys: Bool { isEnabled && suspensions.isEmpty }

    public func setCommand(_ id: CommandID, enabled: Bool) {
        precondition(commandEnabled[id] != nil, "unknown command \(id)")
        commandEnabled[id] = enabled
        Log.info(.engine, "command \(id) \(enabled ? "enabled" : "disabled")")
        stateChanged()
    }

    /// The front app or window changed.
    func contextChanged(to context: FrontContext) {
        Log.info(.context, "front: \(context)")
        self.context = context
        // A press still deciding belongs to the window it was pressed in.
        stateChanged()
        onContextChange?(context)
    }

    /// What decides which keys apply changed: pending presses no longer hold, and the hotkeys are worked out again.
    private func stateChanged() {
        voidPendingInput()
        updateHotKeys()
    }

    // MARK: Matching

    private func isActive(_ command: Command, in context: FrontContext) -> Bool {
        commandEnabled[command.id] == true && command.scope.applies(to: context)
    }

    /// Commands that would fire for this key in this context, best match first. `tie(with:)` keeps two from having the same precedence. A command for the track under the VoiceOver cursor comes first, and the next one runs when the cursor is not on a track.
    public func candidates(for combo: KeyCombo, in context: FrontContext) -> [Command] {
        guard !waitsForWindow(combo, in: context) else { return [] }
        return (commandsByCombo[combo] ?? [])
            .compactMap(command)
            .filter { isActive($0, in: context) }
            .sorted { $0.scope.precedence > $1.scope.precedence }
    }

    /// The commands that offer themselves in the status menu now, like Keyboard Maestro's status menu, which listed the commands of the groups active for the front window: those whose scope applies now.
    public func statusMenuCommands(in context: FrontContext) -> [Command] {
        activeCommands(in: context).filter { $0.triggers.contains(.statusMenu) }
    }

    /// The commands that work in this context, in install order: Flo Tools takes keys, the command is enabled and its scope applies. Inspector commands count in the Mix and Edit windows, because only a press can tell whether the VoiceOver cursor is on a track.
    public func activeCommands(in context: FrontContext) -> [Command] {
        guard takesKeys else { return [] }
        return commands.filter { isActive($0, in: context) }
    }

    public func activeCombos(in context: FrontContext) -> Set<KeyCombo> {
        Set(commandsByCombo.filter { combo, ids in
            !waitsForWindow(combo, in: context) && ids.contains { id in command(id).map { isActive($0, in: context) } ?? false }
        }.keys)
    }

    /// Whether this key's command depends on a Pro Tools window that is not known yet, as for a moment after Pro Tools is activated, before its window title is read: some window kind has a command of its own for the key. Its any-window command would then be a guess, for example Shift+Up announcing a playlist in Batch Fades, so the key goes on to Pro Tools instead.
    private func waitsForWindow(_ combo: KeyCombo, in context: FrontContext) -> Bool {
        guard context.bundleID == ProToolsApp.bundleID, context.proToolsWindowKind == nil else { return false }
        return (commandsByCombo[combo] ?? []).contains { id in
            guard let command = command(id), commandEnabled[id] == true else { return false }
            return command.scope.windowKinds != nil
        }
    }

    /// Ends the repeating of keys that stopped being hotkeys and, once started, registers the hotkeys. Repeating ends before `start()` too, so the tests, which dispatch keys without registering them, cover it.
    private func updateHotKeys() {
        guard started || !holds.isEmpty else { return }
        let combos = takesKeys ? activeCombos(in: context) : []
        // A held key that is no longer a hotkey would never report its release, so its repeating ends now.
        endHolds { !combos.contains($0) }
        if started { hotKeys.setActive(combos) }
    }

    // MARK: Running

    private func handle(_ combo: KeyCombo, _ phase: KeyPhase) {
        // Route on the cached context: reading the window here would block every key while Pro Tools is busy. Only a change of front app, which needs no Accessibility call to notice, is checked first.
        let refreshed = contextMonitor.refreshIfFrontAppChanged()
        if refreshed != context { contextChanged(to: refreshed) }
        // Every key is for Pro Tools, so a press while another process has the keyboard, such as the Dock or Spotlight, goes to that process untouched. Releases still go through `dispatch`, which ends repeating started before the focus moved.
        if phase == .pressed, let focus = contextMonitor.keyboardFocusElsewhere() {
            // The key is not named: keys passed on must not appear in the log.
            Log.info(.engine, "keyboard focus is in \(focus.bundleID ?? "pid \(focus.processID)"), not \(context), passing the key on")
            passThrough(combo, to: focus)
            return
        }
        if dispatch(combo, phase, in: context) == nil {
            if phase == .pressed {
                // The key is not named: keys no command matched must not appear in the log.
                Log.info(.engine, "Flo Tools takes no keys now, passing the key on")
                passThrough(combo, to: context)
            }
            updateHotKeys()
        }
    }

    /// Admits a press, in `context`, which becomes the engine's current one: queued runs are checked against it. A release lets go of its press and ends its repeating. Returns the invocation ID of the press, or of the repeating a release ended; nil when Flo Tools takes no keys or a release ended nothing.
    @discardableResult
    func dispatch(_ combo: KeyCombo, _ phase: KeyPhase, in context: FrontContext, at arrival: ContinuousClock.Instant = .now) -> String? {
        if self.context != context { contextChanged(to: context) }
        switch phase {
        case .pressed:
            guard takesKeys else { return nil }
            return admit(combo, in: context, at: arrival)
        case .released:
            presses.removeValue(forKey: combo)?.released = true
            guard let hold = holds[combo] else { return nil }
            endHolds { $0 == combo }
            return hold.invocation
        }
    }

    /// The command with `id`, or nil after logging that it is missing. App code names commands by ID, so a missing one is a programming error, not a user's.
    private func installedCommand(_ id: CommandID) -> Command? {
        guard let command = command(id) else {
            Log.error(.engine, "command \(id) is not installed")
            return nil
        }
        return command
    }

    /// Runs a command from the app, for example a status menu item. Errors are spoken like those of hotkey runs.
    public func run(_ id: CommandID) {
        guard let command = installedCommand(id) else { return }
        _ = start(command, origin: .direct, context: context, reason: "run by the app", invocation: newInvocation(at: .now, .immediate))
    }

    /// Runs a command because `event` happened, if it could run from a hotkey now: Flo Tools is on and not suspended, and the command is on and its scope applies. Checked again when the run reaches the front of the queue, like a hotkey run.
    public func fire(_ id: CommandID, on event: String) {
        guard let command = installedCommand(id) else { return }
        guard takesKeys, isActive(command, in: context) else {
            Log.info(.engine, "\(event): \(id) is not active in \(context)")
            return
        }
        _ = start(command, origin: .event(event), context: context, reason: event, invocation: newInvocation(at: .now, .immediate))
    }

    /// `start` for a hot key, with the log line live tests look for: `<combo> pressed in <context> -> <command ID>`.
    private func start(_ command: Command, hotKey combo: KeyCombo, in context: FrontContext, invocation: Invocation) -> String {
        start(command, origin: .hotKey(combo), context: context, reason: "\(combo) pressed in \(context)", invocation: invocation)
    }

    /// Starts the run, waiting first to tell a tap from a hold where the command has both. Returns the invocation ID.
    private func start(_ command: Command, origin: CommandRun.Origin, context: FrontContext, reason: String, invocation: Invocation) -> String {
        let press = invocation.press
        // Tasks created in this scope inherit the invocation ID, so taps decided later carry it too.
        Log.$invocation.withValue(invocation.id) {
            Log.info(.engine, "\(reason) -> \(command.id) \"\(command.name)\"")
            var run = CommandRun(command: command, origin: origin, context: context, engine: self)
            run.inspectorTarget = invocation.target
            // The track found at the press may be out of date once what the press was admitted under changes; the queue checks the rest of a run itself.
            if invocation.target != nil { run.inputGeneration = invocation.generation }
            switch command.action {
            case .body(let body):
                enqueue(run, body)
            case .repeating(let body):
                let first = enqueue(run, body)
                guard case .hotKey(let combo) = origin, press?.released != true else { return }
                let timing = keyRepeat()
                let repeats = Task { @MainActor [weak self] in
                    var step = first
                    try? await Task.sleep(for: timing.delay)
                    // The key-down check also stops a repeat whose release never arrived, which would otherwise move a fader to its end.
                    while await step.value, !Task.isCancelled, press?.released != true, timing.isHeld(combo), let self {
                        Log.info(.engine, "repeat")
                        step = self.enqueue(run) { run in
                            guard await MainActor.run(body: { press?.released != true }) else { throw CancellationError() }
                            try await body(run)
                        }
                        try? await Task.sleep(for: timing.interval)
                    }
                }
                holds[combo] = Hold(run: run, end: {
                    press?.released = true
                    repeats.cancel()
                }, invocation: invocation.id)
            case .tapOrHold(let tap, let hold, let doneSound):
                startTapOrHold(run, tap: tap, hold: Self.withDoneSound(hold, doneSound), invocation: invocation)
            }
        }
        return invocation.id
    }

    /// Runs `hold` once the key has stayed down for the hold time, or `tap` as soon as it is let go. A run not started by a key press runs its tap at once.
    private func startTapOrHold(_ run: CommandRun, tap: @escaping CommandBody, hold: @escaping CommandBody, invocation: Invocation) {
        let id = run.command.id
        // A tap still waiting when its key goes down again was let go, so it runs first.
        flushTap(id)
        guard case .hotKey(let combo) = run.origin, let press = invocation.press else {
            Log.info(.engine, "tap")
            enqueue(run, tap)
            return
        }
        let holdEnds = invocation.arrival + holdTime
        let task = Task { @MainActor [weak self] in
            let held = await self?.staysDown(combo, press: press, until: holdEnds) == true
            guard let self, !Task.isCancelled else { return }
            self.pendingTaps[id] = nil
            Log.info(.engine, held ? "held" : "tap")
            self.enqueue(run, held ? hold : tap)
        }
        pendingTaps[id] = PendingTap(task: task, run: run, body: tap, invocation: invocation)
    }

    /// Whether `combo` stays down until `deadline`; false when cancelled. The key's release event ends the wait at once. The physical key state is also checked every 20 ms, for a release event that never arrives, so a release and a new press in between count as released.
    private func staysDown(_ combo: KeyCombo, press: Press, until deadline: ContinuousClock.Instant) async -> Bool {
        let timing = keyRepeat()
        while !press.released, timing.isHeld(combo), !Task.isCancelled {
            let now = ContinuousClock.now
            if now >= deadline { return true }
            let nap = Task { _ = try? await Task.sleep(until: min(now + .milliseconds(20), deadline)) }
            press.nap = nap
            await nap.value
        }
        return false
    }

    /// Registers a new `Press` for `combo`, marking any earlier one released, so `dispatch` can mark this one's release.
    private func trackRelease(of combo: KeyCombo) -> Press {
        let press = Press()
        presses[combo]?.released = true
        presses[combo] = press
        return press
    }

    private static func withDoneSound(_ hold: @escaping CommandBody, _ doneSound: DoneSoundTiming) -> CommandBody {
        switch doneSound {
        case .beforeHold:
            return { run in
                await Sound.done.play()
                try await hold(run)
            }
        case .afterHold:
            return { run in
                try await hold(run)
                await Sound.done.play()
            }
        case .none:
            return hold
        }
    }

    /// Adds a top-level run to the serial queue. Its errors end here: logged, and spoken through `SpokenError`. The task tells whether the run finished, for a repeating command's next run.
    @discardableResult
    private func enqueue(_ run: CommandRun, _ body: @escaping CommandBody) -> Task<Bool, Never> {
        queuedCount += 1
        let number = queuedCount
        let previous = queueTail
        let task = Task { @MainActor [weak self] in
            _ = await previous?.value
            let start = ContinuousClock.now
            defer { self?.runs[number] = nil }
            if let reason = self?.invalidReason(run) {
                Log.info(.engine, "\(run.command.id) dropped: \(reason)")
                return false
            }
            do {
                try Task.checkCancellation()
                try await body(run)
                Log.info(.engine, "\(run.command.id) finished (\(Log.elapsed(since: start)))")
                return true
            } catch is CancellationError {
                Log.info(.engine, "\(run.command.id) cancelled (\(Log.elapsed(since: start)))")
            } catch {
                Log.error(.engine, "\(run.command.id) failed: \(error) (\(Log.elapsed(since: start)))")
                if let text = SpokenError.text(for: error) { await VoiceOver.sayOrLog(text) }
            }
            return false
        }
        runs[number] = task
        queueTail = task
        return task
    }

    /// Why a queued hotkey or event run must not start any more, or nil if it may. Checked when it reaches the front of the queue, because Flo Tools, the command or the front app may have changed while it waited.
    private func invalidReason(_ run: CommandRun) -> String? {
        switch run.origin {
        case .hotKey, .event: break
        case .direct: return nil
        }
        if let generation = run.inputGeneration, generation != inputGeneration { return "the track under the cursor was found before a change" }
        if !isEnabled { return "Flo Tools is disabled" }
        if let suspension = suspensions.first { return "suspended: \(suspension)" }
        if commandEnabled[run.command.id] != true { return "command disabled" }
        if context.processID != run.context.processID { return "another app is in front" }
        if !run.command.scope.applies(to: context) { return "not in its windows: \(context)" }
        // A command for some windows acts on the front window, which must still be the one it was pressed in: another window of the same kind, such as a second instance of one plug-in, is not that window.
        if run.command.scope.windowKinds != nil, run.context.windowNumber != context.windowNumber { return "another window is in front: \(context)" }
        return nil
    }

    /// Ends the repeating started on a track under the cursor, which may no longer be the track there.
    private func endTrackHolds() {
        endHolds { holds[$0]?.run.inspectorTarget != nil }
    }

    /// Ends the repeating of the keys that match.
    private func endHolds(where ends: (KeyCombo) -> Bool) {
        for combo in holds.keys.filter(ends) {
            guard let hold = holds.removeValue(forKey: combo) else { continue }
            Log.$invocation.withValue(hold.invocation) {
                Log.info(.engine, "\(hold.run.command.id) repeating of \(combo) ended")
                hold.end()
            }
        }
    }

    func waitForAdmissions() async {
        while admissions > 0 { await admissionTail?.value }
    }

    /// Waits for input decisions, pending taps and the command queue. Repeating and watches end independently.
    func waitUntilIdle() async {
        await waitForAdmissions()
        for tap in Array(pendingTaps.values) { await tap.task.value }
        while let tail = queueTail, runs.isEmpty == false { _ = await tail.value }
    }

    /// Sends a key Carbon took from the front app on to it, from the hotkey callback, without waiting. Posted to the process, so the key is not caught as a hotkey again.
    private func passThrough(_ combo: KeyCombo, to context: FrontContext) {
        guard context.processID > 0 else {
            Log.warning(.engine, "no front app to pass a key on to, the key is lost")
            return
        }
        postKey(combo, context)
    }
}
