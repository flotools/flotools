import ApplicationServices
import Foundation
import Testing
@testable import FloFeatures
@testable import FloEngine
@testable import FloProTools
@testable import FloSystem

@Suite struct ScopeTests {
    let proTools = ProToolsApp.bundleID

    @Test func scopesApplyInTheirWindows() {
        #expect(Scope.mixOrEdit.applies(to: FrontContext(bundleID: proTools, windowTitle: "Mix: I Trust")))
        #expect(Scope.mixOrEdit.applies(to: FrontContext(bundleID: proTools, windowTitle: "Edit: I Trust")))
        #expect(!Scope.mixOrEdit.applies(to: FrontContext(bundleID: proTools, windowTitle: "Untitled Edit: S")))
        #expect(!Scope.mixOrEdit.applies(to: FrontContext(bundleID: proTools, windowTitle: "Plug-in: EQ3")))
        #expect(!Scope.mixOrEdit.applies(to: FrontContext(bundleID: proTools)))
        #expect(!Scope.mixOrEdit.applies(to: FrontContext(bundleID: "com.apple.finder", windowTitle: "Mix: I Trust")))
        #expect(Scope.windows([.fade(.fadeIn)]).applies(to: FrontContext(bundleID: proTools, windowTitle: "Fade In")))
        #expect(!Scope.windows([.fade(.fadeIn)]).applies(to: FrontContext(bundleID: proTools, windowTitle: "Fade In Out")))
        #expect(Scope.anyProToolsWindow.applies(to: FrontContext(bundleID: proTools)))
        #expect(!Scope.anyProToolsWindow.applies(to: FrontContext(bundleID: "com.apple.finder")))
    }

    @Test func trackScopeAppliesInMixAndEdit() {
        #expect(Scope.trackUnderVoiceOverCursor.applies(to: FrontContext(bundleID: proTools, windowTitle: "Mix: I Trust")))
        #expect(Scope.trackUnderVoiceOverCursor.applies(to: FrontContext(bundleID: proTools, windowTitle: "Edit: I Trust")))
        #expect(!Scope.trackUnderVoiceOverCursor.applies(to: FrontContext(bundleID: proTools, windowTitle: "Plug-in: EQ3")))
        #expect(!Scope.trackUnderVoiceOverCursor.applies(to: FrontContext(bundleID: proTools)))
    }

    /// Two commands may share a key only if one has the higher precedence or they can never apply together.
    @MainActor @Test func tiesAreFound() {
        func command(_ id: CommandID, _ scope: Scope, key: String = "Cmd+1") -> Command {
            Command(id, "Test", scope: scope, triggers: [.key(key)]) { _ in }
        }
        let engine = FloFeatures.makeEngine(commands: [command("test.any", .anyProToolsWindow), command("test.plugIn", .windows([.plugIn])), command("test.track", .trackUnderVoiceOverCursor)])
        #expect(engine.tie(with: command("test.any2", .anyProToolsWindow)) != nil)
        #expect(engine.tie(with: command("test.plugIn2", .windows([.plugIn, .audioSuite]))) != nil)
        #expect(engine.tie(with: command("test.track2", .trackUnderVoiceOverCursor)) != nil)
        #expect(engine.tie(with: command("test.trackView", .mixOrEdit)) == nil, "the track command comes first, and this one runs off a track")
        #expect(engine.tie(with: command("test.audioSuite", .windows([.audioSuite]))) == nil)
        #expect(engine.tie(with: command("test.otherKey", .anyProToolsWindow, key: "Cmd+2")) == nil)
    }
}

@MainActor @Suite struct EngineTests {
    static let proTools = ProToolsApp.bundleID
    let mix = FrontContext(bundleID: proTools, windowTitle: "Mix: Session")
    let plugin = FrontContext(bundleID: proTools, windowTitle: "Plug-in: EQ3 7-Band")

    @Test func allCommandsInstall() {
        let engine = FloFeatures.makeEngine()
        #expect(engine.commands.count == FloFeatures.all().count)
        #expect(engine.command("inspector.speakOpenSendB")?.hotKeys.map(\.description) == ["Ctrl+2"])
    }

    @Test func onlyCommandsInMatchingContextAreActive() {
        let engine = FloFeatures.makeEngine(commands: [])
        let ctrl2 = KeyCombo(keyCode: 19, modifiers: KeyCombo.control)
        #expect(engine.activeCombos(in: mix).isEmpty)

        engine.install(Command("test.sendB", "Send B", scope: .trackUnderVoiceOverCursor, triggers: [.key("Ctrl+2")]) { _ in })
        #expect(engine.activeCombos(in: mix) == [ctrl2])
        #expect(engine.candidates(for: ctrl2, in: mix).map(\.id) == ["test.sendB"])
        #expect(engine.activeCombos(in: plugin).isEmpty)

        engine.setCommand("test.sendB", enabled: false)
        #expect(engine.activeCombos(in: mix).isEmpty)
    }

    /// The more specific scope comes first; a track command keeps the next one as what the key does off a track.
    @Test func narrowerScopesComeFirst() {
        // Cmd+1 is "Tab 1" in setup windows, "Assign Insert A" in the Inspector and "Load Plug-In Parameters for View 1" in plug-in windows; here an any-window binding stands in for a general key.
        let engine = FloFeatures.makeEngine(commands: [])
        for (id, scope) in [("test.any", Scope.anyProToolsWindow), ("test.track", .trackUnderVoiceOverCursor), ("test.plugIn", .windows([.plugIn]))] {
            engine.install(Command(CommandID(id), "Cmd+1", scope: scope, triggers: [.key("Cmd+1")]) { _ in })
        }
        let cmd1 = KeyCombo(keyCode: 18, modifiers: KeyCombo.command)
        #expect(engine.candidates(for: cmd1, in: plugin).map(\.id) == ["test.plugIn", "test.any"])
        #expect(engine.candidates(for: cmd1, in: mix).map(\.id) == ["test.track", "test.any"])
    }

    /// While the window is not known yet, a key that some window gives to its own command is not taken, so the any-window command cannot run in the wrong window; a key no window overrides still works.
    @Test func unknownWindowLeavesWindowDecidedKeysToProTools() {
        let engine = FloFeatures.makeEngine(commands: [])
        engine.install(Command("test.playlist", "Shift+Up", scope: .anyProToolsWindow, triggers: [.key("Shift+Up")]) { _ in })
        engine.install(Command("test.batchFades", "Shift+Up", scope: .windows([.fade(.batchFades)]), triggers: [.key("Shift+Up")]) { _ in })
        engine.install(Command("test.grid", "Cmd+F8", scope: .anyProToolsWindow, triggers: [.key("Cmd+F8")]) { _ in })
        let unknown = FrontContext(bundleID: Self.proTools, windowTitle: nil)
        let shiftUp = KeyCombo("Shift+Up")!, cmdF8 = KeyCombo("Cmd+F8")!
        #expect(engine.candidates(for: shiftUp, in: unknown).isEmpty)
        #expect(engine.activeCombos(in: unknown) == [cmdF8])
        #expect(engine.candidates(for: shiftUp, in: mix).map(\.id) == ["test.playlist"])
        #expect(engine.candidates(for: shiftUp, in: FrontContext(bundleID: Self.proTools, windowTitle: "Batch Fades")).first?.id == "test.batchFades")
        // A disabled window command decides nothing.
        engine.setCommand("test.batchFades", enabled: false)
        #expect(engine.activeCombos(in: unknown) == [cmdF8, shiftUp])
        #expect(engine.candidates(for: shiftUp, in: unknown).map(\.id) == ["test.playlist"])
        // A track command also decides by window.
        engine.install(Command("test.trackF8", "Cmd+F8", scope: .trackUnderVoiceOverCursor, triggers: [.key("Cmd+F8")]) { _ in })
        #expect(engine.candidates(for: cmdF8, in: unknown).isEmpty)
    }

    @Test func trackKeysRegisterInMixAndEdit() {
        let engine = FloFeatures.makeEngine()
        let solo = KeyCombo(literal: "S")
        #expect(engine.activeCombos(in: mix).contains(solo))
        #expect(engine.activeCombos(in: FrontContext(bundleID: Self.proTools, windowTitle: "Edit: Session")).contains(solo))
        #expect(!engine.activeCombos(in: plugin).contains(solo))
        #expect(!engine.activeCombos(in: FrontContext(bundleID: Self.proTools)).contains(solo))
        engine.setCommand("inspector.speakToggleSolo", enabled: false)
        #expect(!engine.activeCombos(in: mix).contains(solo))
    }

    /// On a track, Ctrl+Cmd+Right pans; off a track it is Pro Tools' track view key.
    @Test func ctrlCmdArrowsPanOnATrackAndChangeTrackViewOffIt() {
        let engine = FloFeatures.makeEngine()
        let right = KeyCombo("Ctrl+Cmd+Right")!
        let edit = FrontContext(bundleID: Self.proTools, windowTitle: "Edit: Session")
        #expect(engine.candidates(for: right, in: edit).map(\.id) == ["inspector.panRightOnMonoLeftChannel", KeyAnnouncements.nextTrackViewOnSelectedTracks])
        #expect(engine.candidates(for: KeyCombo("S")!, in: edit).map(\.id) == ["inspector.speakToggleSolo"])
    }
}

@MainActor @Suite struct WatchesTests {
    /// A cancelled watch makes no further read, whether it was cancelled before or during the wait.
    @Test func waitForNextPollStopsOnCancellation() async {
        let before = Task { withUnsafeCurrentTask { $0?.cancel() }; return await Watches.waitForNextPoll() }
        #expect(await before.value == false)
        let during = Task { await Watches.waitForNextPoll() }
        during.cancel()
        #expect(await during.value == false)
        #expect(await Watches.waitForNextPoll() == true)
    }

    /// A watch body that reports when it starts and when it ends, and runs until cancelled.
    final class Probe: Sendable {
        let events: AsyncStream<String>
        let continuation: AsyncStream<String>.Continuation
        init() { (events, continuation) = AsyncStream.makeStream() }
        var body: Watches.Body {
            { [continuation] in
                continuation.yield("started")
                while !Task.isCancelled { try? await Task.sleep(for: .seconds(60)) }
                continuation.yield("ended")
            }
        }
    }

    @Test func toggleStartsAndStops() async {
        let watches = Watches()
        let probe = Probe()
        var events = probe.events.makeAsyncIterator()
        #expect(watches.toggle("inspector.a", probe.body))
        #expect(await events.next() == "started")
        #expect(watches.isRunning("inspector.a"))
        #expect(!watches.toggle("inspector.a", probe.body))
        #expect(await events.next() == "ended")
        #expect(!watches.isRunning("inspector.a"))
    }

    @Test func aStoppedWatchEndingLateDoesNotForgetItsReplacement() async {
        let watches = Watches()
        let first = Probe(), second = Probe()
        var firstEvents = first.events.makeAsyncIterator(), secondEvents = second.events.makeAsyncIterator()
        watches.toggle("inspector.a", first.body)
        #expect(await firstEvents.next() == "started")
        watches.toggle("inspector.a", first.body)
        watches.toggle("inspector.a", second.body)
        #expect(await firstEvents.next() == "ended")
        #expect(await secondEvents.next() == "started")
        await Task.yield()
        #expect(watches.isRunning("inspector.a"))
        watches.stopAll()
        #expect(await secondEvents.next() == "ended")
        #expect(!watches.isRunning("inspector.a"))
    }

    /// A watch stopped on its own may still be ending; a later `stopAll()`, as when Pro Tools quits and session state is reset, waits for it too, and so does a second `stopAll()`.
    /// The watch reaches its goodbye before anything is checked, and the gate opens only after the check that nothing finished early, so correct code always passes. The 50 ms only give broken code time to show itself.
    @Test func stopAllWaitsForAWatchStoppedEarlier() async throws {
        let watches = Watches()
        let gate = Gate(), ended = Flag(), joined = Flag()
        let (progress, report) = AsyncStream<String>.makeStream()
        watches.toggle("inspector.a") {
            report.yield("started")
            try? await Task.sleep(for: .seconds(60))
            // Cancelled: say goodbye, which takes until the gate opens.
            report.yield("at gate")
            await gate.wait()
            await ended.set()
        }
        var steps = progress.makeAsyncIterator()
        #expect(await steps.next() == "started")
        watches.stop("inspector.a")
        #expect(!watches.isRunning("inspector.a"))
        #expect(await steps.next() == "at gate")
        let first = watches.stopAll(), second = watches.stopAll()
        let joiner = Task {
            await first.value
            await second.value
            await joined.set()
        }
        try await Task.sleep(for: .milliseconds(50))
        #expect(await !joined.isSet)
        await gate.open()
        await joiner.value
        #expect(await ended.isSet)
    }

    @Test func aWatchThatEndsByItselfIsForgotten() async {
        let watches = Watches()
        let (ended, continuation) = AsyncStream<Void>.makeStream()
        watches.toggle("inspector.a") { continuation.yield() }
        var iterator = ended.makeAsyncIterator()
        _ = await iterator.next()
        while watches.isRunning("inspector.a") { await Task.yield() }
        #expect(!watches.isRunning("inspector.a"))
    }
}

/// Opens once; waiting ignores cancellation, like a watch's goodbye.
private actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters = []
    }
}

private actor Flag {
    private(set) var isSet = false
    func set() { isSet = true }
}

/// Runs commands through the engine without hotkeys: `dispatch` is what a hotkey press calls after reading the context.
@MainActor @Suite struct CommandRunTests {
    let mix = FrontContext(bundleID: ProToolsApp.bundleID, windowTitle: "Mix: Session")

    @MainActor final class Events {
        var list: [String] = []
    }

    /// An engine whose passed-on keys are recorded as "passed on" rather than posted.
    func engine(_ commands: [Command], events: Events? = nil) -> Engine {
        let engine = FloFeatures.makeEngine(commands: commands)
        engine.postKey = { _, _ in events?.list.append("passed on") }
        return engine
    }

    func tapOrHoldCommand(_ events: Events) -> Command {
        Command("test.speak", "Speak", scope: .anyProToolsWindow, triggers: [.key("F1")], tap: { @MainActor _ in events.list.append("tap") }, hold: { @MainActor _ in events.list.append("hold") })
    }

    /// A change of what decides the keys voids a press still telling a tap from a hold.
    @Test func disablingACommandVoidsAPendingTap() async throws {
        let events = Events()
        let engine = tapOrHoldEngine(events, holdTime: .milliseconds(80), held: .down)
        engine.install(Command("test.other", "Other", scope: .anyProToolsWindow, triggers: []) { @MainActor _ in })
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        await engine.waitForAdmissions()
        engine.setCommand("test.other", enabled: false)
        await engine.waitUntilIdle()
        #expect(events.list.isEmpty)
    }

    /// A key that no command takes goes on to the front app.
    @Test func unboundKeyIsPassedOn() async {
        let events = Events()
        let engine = engine([], events: events)
        engine.dispatch(KeyCombo("F9")!, .pressed, in: FrontContext(bundleID: ProToolsApp.bundleID, windowTitle: "Mix: Session", processID: 100))
        await engine.waitUntilIdle()
        #expect(events.list == ["passed on"])
    }

    /// A queued command for some windows is dropped when another window of the same kind comes to front before it starts, such as a second instance of one plug-in with the same title; an any-window command still runs.
    @Test(arguments: ["Plug-in: EQ3", "Plug-in: Pro-Q 3"])
    func queuedWindowCommandDropsWhenAnotherWindowComesToFront(_ nextTitle: String) async throws {
        let events = Events()
        let engine = engine(slowThenFast(events) + [plugInCommand(events)])
        let first = plugInWindow
        engine.contextChanged(to: first)
        engine.dispatch(KeyCombo("F1")!, .pressed, in: first)
        engine.dispatch(KeyCombo("F3")!, .pressed, in: first)
        engine.dispatch(KeyCombo("F2")!, .pressed, in: first)
        // Admitted first, as presses are within moments when no cursor check is needed; a change during admission voids them.
        await engine.waitForAdmissions()
        engine.contextChanged(to: FrontContext(bundleID: ProToolsApp.bundleID, windowTitle: nextTitle, windowNumber: 2, processID: 100))
        await engine.waitUntilIdle()
        #expect(events.list == ["slow start", "slow end", "fast"])
    }

    @Test func queuedWindowCommandRunsWhileItsWindowStaysInFront() async throws {
        let events = Events()
        let engine = engine(slowThenFast(events) + [plugInCommand(events)])
        let front = plugInWindow
        engine.contextChanged(to: front)
        engine.dispatch(KeyCombo("F1")!, .pressed, in: front)
        engine.dispatch(KeyCombo("F3")!, .pressed, in: front)
        await engine.waitUntilIdle()
        #expect(events.list == ["slow start", "slow end", "plug-in"])
    }

    let plugInWindow = FrontContext(bundleID: ProToolsApp.bundleID, windowTitle: "Plug-in: EQ3", windowNumber: 1, processID: 100)

    func plugInCommand(_ events: Events) -> Command {
        Command("test.plugIn", "Plug-in", scope: .windows([.plugIn]), triggers: [.key("F3")]) { @MainActor _ in events.list.append("plug-in") }
    }

    @Test func topLevelRunsDoNotInterleave() async throws {
        let events = Events()
        let engine = engine(slowThenFast(events))
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        engine.dispatch(KeyCombo("F2")!, .pressed, in: mix)
        await engine.waitUntilIdle()
        #expect(events.list == ["slow start", "slow end", "fast"])
    }

    func slowThenFast(_ events: Events) -> [Command] {
        [
            Command("test.slow", "Slow", scope: .anyProToolsWindow, triggers: [.key("F1")]) { @MainActor _ in
                events.list.append("slow start")
                try await Task.sleep(for: .milliseconds(50))
                events.list.append("slow end")
            },
            Command("test.fast", "Fast", scope: .anyProToolsWindow, triggers: [.key("F2")]) { @MainActor _ in events.list.append("fast") },
        ]
    }

    /// An event, such as a plug-in window coming to front, starts a command only when a hotkey could: not while suspended, and not outside its scope.
    @Test func eventRunsOnlyWhereAHotkeyWould() async throws {
        let events = Events()
        let engine = engine([Command("test.event", "Event", scope: .anyProToolsWindow, triggers: []) { @MainActor _ in events.list.append("ran") }])
        engine.dispatch(KeyCombo("F9")!, .pressed, in: FrontContext(bundleID: "com.apple.finder", windowTitle: "Desktop"))
        engine.fire("test.event", on: "test event")
        engine.dispatch(KeyCombo("F9")!, .pressed, in: mix)
        let paused = Suspension("test")
        engine.suspend(paused)
        engine.fire("test.event", on: "test event")
        engine.resume(paused)
        engine.fire("test.event", on: "test event")
        await engine.waitUntilIdle()
        #expect(events.list == ["ran"])
    }

    @Test func queuedRunIsDroppedWhenItsCommandIsDisabled() async throws {
        let events = Events()
        let engine = engine(slowThenFast(events))
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        engine.dispatch(KeyCombo("F2")!, .pressed, in: mix)
        await engine.waitForAdmissions()
        engine.setCommand("test.fast", enabled: false)
        await engine.waitUntilIdle()
        #expect(events.list == ["slow start", "slow end"])
    }

    @Test func queuedRunIsDroppedWhenAnotherAppIsInFront() async throws {
        let events = Events()
        let (started, signalStarted) = AsyncStream<Void>.makeStream()
        let (finish, signalFinish) = AsyncStream<Void>.makeStream()
        let engine = engine([
            Command("test.slow", "Slow", scope: .anyProToolsWindow, triggers: [.key("F1")]) { @MainActor [signalStarted] _ in
                signalStarted.yield()
                for await _ in finish { break }
                events.list.append("slow")
            },
            Command("test.fast", "Fast", scope: .anyProToolsWindow, triggers: [.key("F2")]) { @MainActor _ in events.list.append("fast") },
        ], events: events)
        let proTools = FrontContext(bundleID: ProToolsApp.bundleID, windowTitle: "Mix: Session", processID: 100)
        engine.dispatch(KeyCombo("F1")!, .pressed, in: proTools)
        engine.dispatch(KeyCombo("F2")!, .pressed, in: proTools)
        for await _ in started { break }
        // While the slow command runs, Finder comes to front and a key no command takes is pressed.
        engine.dispatch(KeyCombo("F9")!, .pressed, in: FrontContext(bundleID: "com.apple.finder", processID: 200))
        await engine.waitForAdmissions()
        signalFinish.yield()
        await engine.waitUntilIdle()
        #expect(events.list == ["passed on", "slow"])
    }

    /// Counts the key-down checks of a repeating command and answers "held" for the first `heldChecks` of them.
    final class HeldKey: @unchecked Sendable {
        private let lock = NSLock()
        private var checks = 0
        let heldChecks: Int
        init(heldChecks: Int) { self.heldChecks = heldChecks }
        func isHeld() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            checks += 1
            return checks <= heldChecks
        }

        /// A key that stays down, or one that is already up at the first check.
        static var down: HeldKey { HeldKey(heldChecks: .max) }
        static var up: HeldKey { HeldKey(heldChecks: 0) }
    }

    /// Checks the physical key through `held` every 5 ms, so held-key tests run fast.
    func checkKey(of engine: Engine, with held: HeldKey) {
        engine.keyRepeat = { KeyRepeat(delay: .milliseconds(5), interval: .milliseconds(5)) { _ in held.isHeld() } }
    }

    func repeatingEngine(_ events: Events, held: HeldKey, fails: Bool = false) -> Engine {
        let engine = engine([Command.repeatingWhileHeld("test.repeat", "Repeat", scope: .anyProToolsWindow, triggers: [.key("F4")]) { @MainActor _ in
            events.list.append("step")
            if fails { throw CancellationError() }
        }])
        checkKey(of: engine, with: held)
        return engine
    }

    /// Waits until `events` has `count` entries, then a little longer, so a run too many would show.
    func settle(_ events: Events, at count: Int) async throws {
        let start = ContinuousClock.now
        while events.list.count < count, ContinuousClock.now - start < .seconds(2) { try await Task.sleep(for: .milliseconds(5)) }
        try await Task.sleep(for: .milliseconds(60))
    }

    @Test func repeatingRunsUntilTheKeyIsNoLongerDown() async throws {
        let events = Events()
        let engine = repeatingEngine(events, held: HeldKey(heldChecks: 2))
        engine.dispatch(KeyCombo("F4")!, .pressed, in: mix)
        try await settle(events, at: 3)
        // The press, then one run per check that found the key down.
        #expect(events.list == ["step", "step", "step"])
    }

    @Test func repeatingStopsOnRelease() async throws {
        let events = Events()
        let engine = repeatingEngine(events, held: .down)
        engine.dispatch(KeyCombo("F4")!, .pressed, in: mix)
        try await settle(events, at: 2)
        engine.dispatch(KeyCombo("F4")!, .released, in: mix)
        await engine.waitUntilIdle()
        let afterRelease = events.list.count
        try await Task.sleep(for: .milliseconds(60))
        #expect(afterRelease >= 2)
        #expect(events.list.count == afterRelease)
    }

    @Test func repeatingStopsAfterARunThatDidNotFinish() async throws {
        let events = Events()
        let engine = repeatingEngine(events, held: .down, fails: true)
        engine.dispatch(KeyCombo("F4")!, .pressed, in: mix)
        try await settle(events, at: 1)
        #expect(events.list == ["step"])
    }

    /// A repeating command on F4 and an F4 command for the Batch Fades window, so F4 stops being a hotkey while the window is unknown.
    func repeatingEngineWithWindowKey(_ events: Events) -> Engine {
        let engine = repeatingEngine(events, held: .down)
        engine.install(Command("test.batchFadesF4", "F4", scope: .windows([.fade(.batchFades)]), triggers: [.key("F4")]) { _ in })
        return engine
    }

    /// A held key that stops being a hotkey never reports its release, so the engine ends its repeating itself.
    @Test(arguments: ["window unknown", "stopped"]) func repeatingEndsWhenItsKeyStopsBeingAHotkey(_ cause: String) async throws {
        let events = Events()
        let engine = repeatingEngineWithWindowKey(events)
        engine.dispatch(KeyCombo("F4")!, .pressed, in: mix)
        try await settle(events, at: 2)
        if cause == "stopped" { engine.stop() } else { engine.contextChanged(to: FrontContext(bundleID: ProToolsApp.bundleID, windowTitle: nil)) }
        await engine.waitUntilIdle()
        let afterEnd = events.list.count
        try await Task.sleep(for: .milliseconds(60))
        #expect(events.list.count == afterEnd)
    }

    /// An engine with one tap-or-hold command on F1, holding for `holdTime`.
    func tapOrHoldEngine(_ events: Events, holdTime: Duration, held: HeldKey) -> Engine {
        let engine = engine([tapOrHoldCommand(events)])
        engine.holdTime = holdTime
        checkKey(of: engine, with: held)
        return engine
    }

    @Test func heldKeyRunsTheHold() async throws {
        let events = Events()
        let engine = tapOrHoldEngine(events, holdTime: .milliseconds(80), held: .down)
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        try await settle(events, at: 1)
        #expect(events.list == ["hold"])
    }

    /// A tap runs as soon as the key is up, long before the hold time.
    @Test func tapRunsAtOnce() async throws {
        let events = Events()
        let engine = tapOrHoldEngine(events, holdTime: .milliseconds(500), held: .up)
        let start = ContinuousClock.now
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        try await settle(events, at: 1)
        #expect(events.list == ["tap"])
        #expect(ContinuousClock.now - start < .milliseconds(400))
    }

    @Test func keyReleasedBeforeTheHoldTimeRunsTheTap() async throws {
        let events = Events()
        let engine = tapOrHoldEngine(events, holdTime: .milliseconds(150), held: HeldKey(heldChecks: 1))
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        try await settle(events, at: 1)
        #expect(events.list == ["tap"])
    }

    /// The release event ends the hold decision at once, without waiting for the physical key check, which here still reports the key down.
    @Test func releaseEventRunsTheTapAtOnce() async throws {
        let events = Events()
        let engine = tapOrHoldEngine(events, holdTime: .milliseconds(500), held: .down)
        let start = ContinuousClock.now
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        try await Task.sleep(for: .milliseconds(30))
        engine.dispatch(KeyCombo("F1")!, .released, in: mix)
        try await settle(events, at: 1)
        #expect(events.list == ["tap"])
        #expect(ContinuousClock.now - start < .milliseconds(300))
    }

    /// Two quick taps are two taps.
    @Test func twoTapsRunTwice() async throws {
        let events = Events()
        let engine = tapOrHoldEngine(events, holdTime: .milliseconds(80), held: .up)
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        try await settle(events, at: 2)
        #expect(events.list == ["tap", "tap"])
    }

    /// A run from the status menu has no key to hold, so it runs its tap at once.
    @Test func appRunRunsTheTap() async throws {
        let events = Events()
        let engine = tapOrHoldEngine(events, holdTime: .milliseconds(80), held: .down)
        engine.run("test.speak")
        try await settle(events, at: 1)
        #expect(events.list == ["tap"])
    }

    /// A command on F1 that signals `started` when its body runs, then sleeps 5 s and records whether it finished or was cancelled.
    func longCommand(_ events: Events) -> (command: Command, started: AsyncStream<Void>) {
        let (started, signalStarted) = AsyncStream<Void>.makeStream()
        let command = Command("test.long", "Long", scope: .anyProToolsWindow, triggers: [.key("F1")]) { @MainActor [signalStarted] _ in
            signalStarted.yield()
            do {
                try await Task.sleep(for: .seconds(5))
                events.list.append("finished")
            } catch {
                events.list.append("cancelled")
            }
        }
        return (command, started)
    }

    @Test func stopCancelsARunningCommand() async throws {
        let events = Events()
        let (long, started) = longCommand(events)
        let engine = engine([long])
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        // Stop only once the body runs, so the test checks cancellation of a running command, not of a queued one.
        for await _ in started { break }
        engine.stop()
        await engine.waitUntilIdle()
        #expect(events.list == ["cancelled"])
    }

    @Test func suspensionTakesNoKeysAndKeepsTheUserChoice() async throws {
        let events = Events()
        let engine = engine([Command("test.a", "A", scope: .anyProToolsWindow, triggers: [.key("F1")]) { @MainActor _ in events.list.append("a") }])
        let voiceOverOff = Suspension("VoiceOver is not running")
        engine.suspend(voiceOverOff)
        #expect(engine.dispatch(KeyCombo("F1")!, .pressed, in: mix) == nil)
        engine.isEnabled = false
        engine.resume(voiceOverOff)
        #expect(engine.dispatch(KeyCombo("F1")!, .pressed, in: mix) == nil, "resuming must not undo the user's off switch")
        engine.isEnabled = true
        #expect(engine.dispatch(KeyCombo("F1")!, .pressed, in: mix) != nil)
        await engine.waitUntilIdle()
        #expect(events.list == ["a"])
    }

    @Test func cancelAllStopsRunsAndWatchesButKeepsTheEngine() async throws {
        let events = Events()
        let (long, started) = longCommand(events)
        let engine = engine([
            long,
            Command("test.short", "Short", scope: .anyProToolsWindow, triggers: [.key("F2")]) { @MainActor _ in events.list.append("short") },
        ])
        engine.watches.toggle("test.watch") { try? await Task.sleep(for: .seconds(5)) }
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        for await _ in started { break }
        engine.cancelAll()
        await engine.waitUntilIdle()
        #expect(!engine.watches.isRunning("test.watch"))
        engine.dispatch(KeyCombo("F2")!, .pressed, in: mix)
        await engine.waitUntilIdle()
        #expect(events.list == ["cancelled", "short"])
    }

    @Test func cancelAllEndsAfterTheCancelledWorkHasEnded() async {
        let events = Events()
        let (started, signalStarted) = AsyncStream<Void>.makeStream()
        let engine = engine([
            Command("test.long", "Long", scope: .anyProToolsWindow, triggers: [.key("F1")]) { @MainActor [signalStarted] _ in
                signalStarted.yield()
                try? await Task.sleep(for: .seconds(5))
                // Work a run does after it was cancelled, like writing remembered state, still comes before the end of cancelAll.
                await Task.yield()
                events.list.append("run wrote")
            },
        ])
        engine.watches.toggle("test.watch") { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            await Task.yield()
            events.list.append("watch wrote")
        }
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        for await _ in started { break }
        await engine.cancelAll().value
        events.list.append("reset")
        #expect(events.list.sorted() == ["reset", "run wrote", "watch wrote"])
        #expect(events.list.last == "reset")
    }

    @Test func statusMenuListsCommandsThatApply() {
        let engine = FloFeatures.makeEngine()
        let plugIn = FrontContext(bundleID: ProToolsApp.bundleID, windowTitle: "Plug-in: EQ3 7-Band")
        #expect(engine.statusMenuCommands(in: plugIn).map(\.id) == ["plugin.displayPluginViewTemplate"])
        #expect(engine.statusMenuCommands(in: FrontContext(bundleID: ProToolsApp.bundleID, windowTitle: "Mix: Session")).isEmpty)
        engine.isEnabled = false
        #expect(engine.statusMenuCommands(in: plugIn).isEmpty)
    }

    @Test func scopeTellsWhetherItIsLimitedToWindowKinds() {
        #expect(Scope.windows([.edit]).isLimitedToWindowKinds)
        #expect(Scope.windows([.plugIn]).isLimitedToWindowKinds)
        #expect(Scope.trackUnderVoiceOverCursor.isLimitedToWindowKinds)
        #expect(!Scope.anyProToolsWindow.isLimitedToWindowKinds)
    }

    @Test func commandSearchMatchesEveryWordInNameOrShortcuts() {
        let command = Command("test.solo", "Speak Soloed Tracks, Unsolo All Tracks", scope: .anyProToolsWindow, triggers: [.key("Opt+Shift+S"), .statusMenu]) { _ in }
        #expect(command.shortcutText == "Opt+Shift+S, Flo Tools menu")
        #expect(command.matches(search: ""))
        #expect(command.matches(search: "SOLO"))
        #expect(command.matches(search: "sólo  opt+shift"))
        #expect(command.matches(search: "unsolo menu"))
        #expect(!command.matches(search: "solo ctrl"))
    }

    @Test func activeCommandsAreThoseWhoseScopeApplies() {
        let engine = FloFeatures.makeEngine()
        let mix = FrontContext(bundleID: ProToolsApp.bundleID, windowTitle: "Mix: Session")
        let active = engine.activeCommands(in: mix)
        #expect(!active.isEmpty && active.count < engine.commands.count)
        #expect(active.allSatisfy { $0.scope.applies(to: mix) })
        #expect(active.contains { $0.scope == .trackUnderVoiceOverCursor })
        #expect(active.contains { $0.scope == .anyProToolsWindow })
        #expect(!active.contains { $0.scope == .windows([.plugIn]) })
        #expect(engine.activeCommands(in: FrontContext(bundleID: "com.apple.finder", windowTitle: "Desktop")).isEmpty)
        engine.setCommand(active[0].id, enabled: false)
        #expect(engine.activeCommands(in: mix).count == active.count - 1)
        engine.isEnabled = false
        #expect(engine.activeCommands(in: mix).isEmpty)
    }

    @Test func doneSoundTimingMatchesJXA() throws {
        func doneSound(_ id: CommandID) throws -> DoneSoundTiming? {
            let command = try #require(FloFeatures.all().first { $0.id == id })
            guard case .tapOrHold(_, _, let doneSound) = command.action else { return nil }
            return doneSound
        }
        #expect(try doneSound("inspector.speakOpenSendB") == .afterHold)
        #expect(try doneSound("inspector.speakToggleSolo") == .afterHold)
        #expect(try doneSound("floTools.speakSoloedTracksUnsoloAllTracks") == .beforeHold)
    }
}

@Suite struct SpokenErrorTests {
    @Test func wording() {
        #expect(SpokenError.text(for: FloError.notFound("the Mix window")) == "Could not find the Mix window.")
        #expect(SpokenError.text(for: CancellationError()) == nil)
        #expect(SpokenError.text(for: FloError.voiceOver("could not speak: VoiceOver is not running")) == "VoiceOver did not respond.")
        #expect(SpokenError.text(for: FloError.accessibility(operation: "read AXChildren", code: AXError.cannotComplete.rawValue)) == "Pro Tools did not respond.")
        #expect(SpokenError.text(for: FloError.accessibility(operation: "read AXChildren", code: AXError.apiDisabled.rawValue)) == "Flo Tools needs Accessibility access.")
        #expect(SpokenError.text(for: FloError.couldNot("resume the mix groups")) == "Could not resume the mix groups.")
        let partial = FloError.incomplete(done: "Unsoloed 2 of 5 tracks", cause: .accessibility(operation: "AXPress", code: AXError.cannotComplete.rawValue))
        #expect(SpokenError.text(for: partial) == "Unsoloed 2 of 5 tracks. Pro Tools did not respond.")
        // A closed window or a track that is gone is not a busy app, so the freeze wait stops on it.
        #expect(!FloError.accessibility(operation: "read AXTitle", code: AXError.invalidUIElement.rawValue).isBusyApp)
    }
}

@Suite struct AccessibilityReadTests {
    /// Only "no value" and "no such attribute" are absence; a busy or closed window must not read as an empty value.
    @Test func readOutcomes() {
        #expect(AXElement.readOutcome(.success) == .value)
        #expect(AXElement.readOutcome(.noValue) == .absent)
        #expect(AXElement.readOutcome(.attributeUnsupported) == .absent)
        #expect(AXElement.readOutcome(.cannotComplete) == .failure)
        #expect(AXElement.readOutcome(.invalidUIElement) == .failure)
        #expect(AXElement.readOutcome(.apiDisabled) == .failure)
    }

    @Test func readPreviewsAreShort() {
        #expect(AXElement.preview("Kick" as CFString) == "\"Kick\"")
        #expect(AXElement.preview(String(repeating: "a", count: 80) as CFString) == "\"\(String(repeating: "a", count: 60))...\"")
        #expect(AXElement.preview(NSNumber(value: 1)) == "1")
        #expect(AXElement.preview([1, 2, 3] as CFArray) == "3 items")
        #expect(AXElement.preview(AXUIElementCreateSystemWide()) == "an element")
    }

    @Test func attributeDumpValuesAreInFull() {
        #expect(AXElement.fullDescription("Kick" as CFString) == "\"Kick\"")
        #expect(AXElement.fullDescription("Insert Assignment A\n\"Click II\"" as CFString) == "\"Insert Assignment A\\n\"Click II\"\"")
        #expect(AXElement.fullDescription(kCFBooleanTrue) == "true")
        #expect(AXElement.fullDescription(NSNumber(value: 48000)) == "48000")
        #expect(AXElement.fullDescription(["a", "b"] as CFArray) == "[\"a\", \"b\"]")
        #expect(AXElement.fullDescription([AXUIElementCreateSystemWide()] as CFArray) == "1 items")
        var point = CGPoint(x: 10, y: 20)
        let value = AXValueCreate(.cgPoint, &point)!
        #expect(AXElement.fullDescription(value) == "point(10.0, 20.0)")
        var error = AXError.noValue
        #expect(AXElement.fullDescription(AXValueCreate(.axError, &error)!) == "(AXError -25212)")
    }

    @Test func attributeDumpLeavesOutAbsentValuesOnly() {
        var noValue = AXError.noValue
        var unsupported = AXError.attributeUnsupported
        var busy = AXError.cannotComplete
        #expect(AXElement.isAbsent(AXValueCreate(.axError, &noValue)!))
        #expect(AXElement.isAbsent(AXValueCreate(.axError, &unsupported)!))
        #expect(!AXElement.isAbsent(AXValueCreate(.axError, &busy)!))
        #expect(!AXElement.isAbsent("" as CFString))
        var point = CGPoint.zero
        #expect(!AXElement.isAbsent(AXValueCreate(.cgPoint, &point)!))
    }
}

@MainActor @Suite struct VoiceOverTests {
    @Test func failureReasons() {
        #expect(VoiceOver.failureReason(status: -600) == "VoiceOver is not running")
        #expect(VoiceOver.failureReason(status: -1712) == "VoiceOver did not answer within 2 seconds")
        #expect(VoiceOver.failureReason(status: -1743) == "Flo Tools may not control VoiceOver (Automation permission)")
        #expect(VoiceOver.failureReason(status: -1708) == "Apple event error -1708")
    }

    /// The cursor bounds of a clip list cell, as VoiceOver answered them live: top 414, left 1023, bottom 425, right 1327.
    @Test func cursorBoundsRectangle() {
        let edges: [Int16] = [414, 1023, 425, 1327]
        let data = edges.withUnsafeBytes { Data($0) }
        #expect(VoiceOver.frame(quickDrawRect: data) == CGRect(x: 1023, y: 414, width: 304, height: 11))
        #expect(VoiceOver.frame(quickDrawRect: Data([0, 1])) == nil)
    }
}

@Suite struct MouseTests {
    /// The test runner is never the front app, so these must post nothing: the pointer stays where it is.
    @Test func refusesWhenAnotherAppIsInFront() async {
        let before = CGEvent(source: nil)?.location
        #expect(throws: FloError.couldNot("move the mouse, because another app is in front")) { try Mouse.move(to: CGPoint(x: 5, y: 5), ifFront: -1) }
        await #expect(throws: FloError.couldNot("click, because another app is in front")) { try await Mouse.click(at: CGPoint(x: 5, y: 5), ifFront: -1) }
        #expect(throws: FloError.self) { try Mouse.pressButton(at: CGPoint(x: 5, y: 5), ifFront: -1) }
        await #expect(throws: FloError.self) { try await Mouse.drag(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 9, y: 9), ifFront: -1) }
        #expect(CGEvent(source: nil)?.location == before)
    }
}

@Suite @MainActor struct PreferencesTests {
    private let suite = TestDefaults("FloToolsTests")

    @Test func missingValuesAreDefaults() {
        #expect(PreferencesStore(defaults: suite.defaults).current == Preferences())
    }

    /// Uses the literal stored key, so a renamed `Key.holdTime` that would lose saved values fails here.
    @Test(arguments: [9, 250])
    func unsupportedHoldTimeUsesTheDefault(_ stored: Int) {
        let defaults = suite.defaults
        defaults.set(stored, forKey: "doublePressTimeout")
        #expect(PreferencesStore(defaults: defaults).current.holdTime == Preferences().holdTime)
    }

    @Test func descriptionNamesEveryPreference() {
        #expect(Preferences().description == "hold time 200 ms")
    }

    @Test func savedPreferencesAreReadBack() {
        let defaults = suite.defaults
        var preferences = Preferences()
        preferences.holdTime = 400
        PreferencesStore(defaults: defaults).save(preferences)
        #expect(PreferencesStore(defaults: defaults).current == preferences)
    }

    /// The user's off switch survives a relaunch; a first launch starts enabled.
    @Test func floToolsEnabledIsRemembered() {
        let defaults = suite.defaults
        #expect(PreferencesStore(defaults: defaults).floToolsEnabled)
        PreferencesStore(defaults: defaults).floToolsEnabled = false
        #expect(!PreferencesStore(defaults: defaults).floToolsEnabled)
    }

    /// Flo Tools' two update settings start off and survive a relaunch.
    @Test func updateSettingsAreRemembered() {
        let defaults = suite.defaults
        #expect(!PreferencesStore(defaults: defaults).installsUpdatesAutomatically)
        #expect(!PreferencesStore(defaults: defaults).includesBetaUpdates)
        PreferencesStore(defaults: defaults).installsUpdatesAutomatically = true
        PreferencesStore(defaults: defaults).includesBetaUpdates = true
        #expect(PreferencesStore(defaults: defaults).installsUpdatesAutomatically)
        #expect(PreferencesStore(defaults: defaults).includesBetaUpdates)
    }

    @Test(arguments: Preferences.holdTimeChoices)
    func holdTimeChoicesSurviveRelaunchAndApply(_ holdTime: Int) {
        var preferences = Preferences()
        preferences.holdTime = holdTime
        PreferencesStore(defaults: suite.defaults).save(preferences)
        #expect(PreferencesStore(defaults: suite.defaults).current.holdTime == holdTime)
        let engine = FloFeatures.makeEngine()
        FloFeatures.apply(preferences, to: engine)
        #expect(engine.holdTime == .milliseconds(holdTime))
    }

    @Test func holdTimeChoiceBounds() {
        #expect(Preferences.holdTimeChoices == [100, 200, 300, 400, 500])
        #expect(Preferences().holdTime == 200)
    }
}

@Suite struct CommandTextTests {
    @Test func keyComboParsesItsDescription() {
        for code in KeyCombo.keyNames.keys {
            for modifiers: UInt32 in [0, KeyCombo.command, KeyCombo.control | KeyCombo.option | KeyCombo.shift] {
                let combo = KeyCombo(keyCode: code, modifiers: modifiers)
                #expect(KeyCombo(combo.description) == combo, "\(combo)")
            }
        }
        #expect(KeyCombo("Ctrl+Nope") == nil)
    }

    @Test func keyComboModifiersInAnyOrder() {
        #expect(KeyCombo("Shift+Cmd+G") == KeyCombo("Cmd+Shift+G"))
        #expect(KeyCombo("Opt+Ctrl+Keypad +") == KeyCombo(keyCode: 69, modifiers: KeyCombo.control | KeyCombo.option))
        #expect(KeyCombo("Cmd+Cmd+G") == nil)
        #expect(KeyCombo("Cmd+") == nil)
    }

    @Test func keyComboNames() {
        #expect(KeyCombo(keyCode: 1, modifiers: KeyCombo.option | KeyCombo.shift).description == "Opt+Shift+S")
        #expect(KeyCombo(keyCode: 78, modifiers: KeyCombo.control | KeyCombo.option).description == "Ctrl+Opt+Keypad -")
    }

    /// Key literals outside a command's triggers, which building the keymap does not reach.
    @Test func keyLiteralsParse() {
        #expect(ProToolsApp.suspendAllGroupsKey.description == "Shift+Cmd+G")
    }

    @Test func slotMessageIncludesKind() {
        #expect(Inspector.slotMessage(.send, TrackStrip.SlotReading(.send, selectorName: "Send selector B", selectorValue: "unassigned", assignmentValue: "unassigned")) == "Send B. : unassigned")
        #expect(Inspector.slotMessage(.send, TrackStrip.SlotReading(.send, selectorName: "Send selector B", selectorValue: "Bus 1", assignmentValue: "Send Assignment Reverb")) == "Send B. Bus 1: Reverb")
        // Values seen on Kick on 2026-11-02.
        #expect(Inspector.slotMessage(.insert, TrackStrip.SlotReading(.insert, selectorName: "Insert selector A", selectorValue: "inactive", assignmentValue: "SSL Native Channelstrip v6")) == "Insert A. inactive: SSL Native Channelstrip v6")
        #expect(Inspector.slotMessage(.insert, TrackStrip.SlotReading(.insert, selectorName: "Insert selector B", selectorValue: "unassigned", assignmentValue: "unassigned")) == "Insert B. : unassigned")
    }

    @Test func toggleStateTextMatchesJXA() {
        #expect(Inspector.stateText(.solo, "Selected") == "On")
        #expect(Inspector.stateText(.solo, "") == "Off")
        #expect(Inspector.stateText(.solo, "off safe") == "off safe")
        // The JXA mapped Mute's "on state". On 2026-11-02 a muted track showed "on", which the JXA spoke as is; MIDI Mute and record values were seen on Synth Lead.
        #expect(Inspector.stateText(.mute, "on state") == "On")
        #expect(Inspector.stateText(.mute, "on") == "on")
        #expect(Inspector.stateText(.mute, "") == "Off")
        #expect(Inspector.stateText(.instrumentMute, "on state") == "On")
        #expect(Inspector.stateText(.instrumentMute, "") == "Off")
        #expect(Inspector.stateText(.recordEnable, "") == "Not Armed")
        #expect(Inspector.stateText(.recordEnable, "armed") == "armed")
        #expect(Inspector.stateText(.inputMonitor, "Input monitoring disabled") == "Input monitoring disabled")
        #expect(Inspector.stateText(.inputMonitor, "") == "Off")
        // The JXA mapped only "Selected" for Solo, so a soloed track's "on" is spoken as is.
        #expect(Inspector.stateText(.solo, "on") == "on")
    }

    @Test func trackFlagRulesMatchJXAFilters() {
        let kick = "Kick - Audio Track "
        func state(_ flag: TrackFlag, _ name: String, _ value: String) -> Bool? { TrackFlag.state(of: flag, track: TrackKind(trackName: name), buttonState: value) }
        #expect(state(.soloed, kick, "on") == true)
        #expect(state(.soloed, kick, "") == false)
        #expect(state(.soloed, kick, "on, solo safe") == nil)
        #expect(state(.soloed, kick, "Inactive") == nil)
        #expect(state(.soloed, "Master 1 - Master Track ", "on") == nil)
        #expect(state(.soloSafe, kick, "on, solo safe") == true)
        #expect(state(.soloSafe, kick, "") == false)
        #expect(state(.muted, kick, "on") == true)
        #expect(state(.muted, kick, "") == false)
        // Muted only because another track is soloed.
        #expect(state(.muted, kick, "on solo") == nil)
        #expect(state(.recordArmed, kick, "armed") == true)
        #expect(state(.recordArmed, kick, "") == false)
        #expect(state(.recordArmed, kick, "safe") == nil)
        #expect(state(.recordArmed, "Reverb L - Aux Track ", "") == nil)
        #expect(state(.recordArmed, "Drums - Routing Folder Track ", "") == nil)
        #expect(state(.recordSafe, kick, "safe") == true)
        #expect(state(.recordSafe, "Reverb L - Aux Track ", "safe") == nil)
        #expect(state(.inputMonitored, kick, "Input monitoring enabled") == true)
        #expect(state(.inputMonitored, kick, "Input monitoring disabled") == false)
        #expect(state(.inputMonitored, kick, "on") == true)
        #expect(state(.inputMonitored, "Synth Lead - Inst Track ", "Input monitoring is enabled, but delay compensation is disabled.") == nil)
    }

    @Test func trackKindFromStripName() {
        #expect(TrackKind(trackName: "Kick - Audio Track ") == .audio)
        #expect(TrackKind(trackName: "Bass - MIDI Track ") == .midi)
        #expect(TrackKind(trackName: "Synth Lead - Inst Track ") == .instrument)
        #expect(TrackKind(trackName: "Reverb L - Aux Track ") == .aux)
        #expect(TrackKind(trackName: "Reverb L - Auxiliary Track ") == .aux)
        #expect(TrackKind(trackName: "Master 1 - Master Track ") == .master)
        #expect(TrackKind(trackName: "Drums - Routing Folder Track ") == .folder)
        #expect(TrackKind(trackName: "Drums - Basic Folder Track ") == .folder)
        #expect(TrackKind(trackName: "Strings - VCA Track ") == .other)
        #expect(TrackKind(trackName: "Kick") == .other)
        // Only the suffix counts, not a kind named in the user's track name.
        #expect(TrackKind(trackName: "Folder Track Ideas - Audio Track ") == .audio)
        #expect(TrackKind(trackName: "Keys - MIDI Track Copy - Audio Track ") == .audio)
    }

    @Test func trackListRowNames() {
        #expect(TrackList.trackName(selectButtonName: "Selected. Open. Drums - Routing Folder Track ") == "Drums - Routing Folder Track ")
        #expect(TrackList.trackName(selectButtonName: "Closed. Drums - Routing Folder Track ") == "Drums - Routing Folder Track ")
        #expect(TrackList.trackName(selectButtonName: "Kick - Audio Track ") == "Kick - Audio Track ")
        #expect(TrackList.isSelected(selectButtonName: "Selected. Kick - Audio Track "))
        #expect(!TrackList.isSelected(selectButtonName: "Kick - Audio Track "))
    }

    @Test func peakText() {
        #expect(TrackStrip.decibels(meterReading: "minus 3.1") == -3.1)
        #expect(TrackStrip.decibels(meterReading: "3.0") == 3.0)
        #expect(TrackStrip.decibels(meterReading: "0.0") == 0)
        #expect(TrackStrip.decibels(meterReading: "minus ∞") == nil)
        #expect(TrackStrip.decibels(meterReading: "minus 3.5 db") == -3.5)
        #expect(TrackStrip.decibels(meterReading: "minus inf db") == nil)
    }

    @Test func chooserNamesTracksProToolsRefused() {
        let arm = TrackLists.listings.first { $0.name == "List Record-Disabled Tracks" }!
        #expect(TrackLists.unchangedText(arm, ["Kick - Audio Track ", "Snare - Audio Track "]) == "arm: Kick - Audio Track, Snare - Audio Track")
        #expect(SpokenError.text(for: FloError.couldNot(TrackLists.unchangedText(arm, ["Kick - Audio Track "]))) == "Could not arm: Kick - Audio Track.")
    }

    @Test func settingATrackFlagNeedsTheFlagButClearingAcceptsALeftOutTrack() {
        #expect(TrackFlag.isSettled(true, on: true))
        #expect(!TrackFlag.isSettled(false, on: true), "Pro Tools refused to arm")
        #expect(!TrackFlag.isSettled(nil, on: true), "became inactive or safe instead")
        #expect(TrackFlag.isSettled(false, on: false))
        #expect(!TrackFlag.isSettled(true, on: false))
        #expect(TrackFlag.isSettled(nil, on: false))
    }

    @Test func readFailureStreakTracksARunOfFailures() {
        var streak = ReadFailureStreak(reading: "the meter")
        #expect(!streak.isFailing)
        streak.succeeded()
        #expect(!streak.isFailing)
        streak.failed(FloError.notFound("the meter"))
        streak.failed(FloError.notFound("the meter"))
        #expect(streak.isFailing)
        streak.succeeded()
        #expect(!streak.isFailing)
    }

    @Test func panMessageMatchesJXA() {
        #expect(Inspector.panMessage(valueDescription: "70 to the left", knobName: "Pan Knob") == "70 to the left, Pan Knob")
        #expect(Inspector.panMessage(valueDescription: "Centered", knobName: nil) == "Centered")
    }

    @Test func controlTextMatchesJXA() {
        #expect(InspectorControls.spokenText(.automationMode, name: "Automation Mode selector", value: "auto read") == "auto read")
        #expect(InspectorControls.spokenText(.group, name: "Group ID indicator/pop-up", value: "no group") == "No Group")
        #expect(InspectorControls.spokenText(.input, name: "Audio Input Path selector\n\"no input\"", value: "no input") == "\n\"no input\"")
        #expect(InspectorControls.spokenText(.output, name: "MIDI Output selector\nXpand!2 1-1", value: "") == "\nXpand!2 1-1")
        #expect(InspectorControls.spokenText(.timebase, name: "Timebase selector (ticks)", value: "") == " (ticks)")
        #expect(InspectorControls.spokenText(.elasticAudioPlugIn, name: "Current Elastic Audio or ARA Plugin", value: "") == "None")
        #expect(InspectorControls.spokenText(.comments, name: "Comments \"\"", value: "") == "No Comment")
        #expect(InspectorControls.spokenText(.freeze, name: "Not Frozen", value: "") == "Not Frozen")
    }

    /// Every item ends with ". ", the last one too; an empty list is empty.
    @Test func spokenListEndsEveryItem() {
        #expect(SpokenList.sentences([]) == "")
        #expect(SpokenList.sentences(["Kick"]) == "Kick. ")
        #expect(SpokenList.sentences(["Kick", "Snare"]) == "Kick. Snare. ")
    }

    @Test func gridModeTextLikeJXA() {
        #expect(SettingToggles.gridModeText(isOn: true, buttonName: "Absolute Grid mode") == "Grid mode, Absolute ")
        #expect(SettingToggles.gridModeText(isOn: false, buttonName: "Absolute Grid mode") == "Grid mode, off")
    }

    @Test func inputMonitorTextNamesTheModeSwitchedTo() {
        #expect(SettingToggles.inputMonitorText(itemName: "Set Record Tracks to Auto Input") == "Input Only")
        #expect(SettingToggles.inputMonitorText(itemName: "Set Record Tracks to Input Only") == "Auto Input")
    }

    @Test func gainReductionDecibelsLikeParseInt() {
        #expect(GainReductionPeak.decibels("minus 3 db") == -3)
        #expect(GainReductionPeak.decibels("minus 3.7 db") == -3)
        #expect(GainReductionPeak.decibels("0 db") == 0)
        #expect(GainReductionPeak.decibels("") == nil)
        // Readings Int cannot hold are skipped rather than trapping.
        #expect(GainReductionPeak.decibels("minus inf db") == nil)
        #expect(GainReductionPeak.decibels("nan db") == nil)
        #expect(GainReductionPeak.decibels("1e300 db") == nil)
    }

    @Test func gainReductionPeakKeepsTheDeepestAndStartsOver() async {
        let peak = GainReductionPeak()
        await peak.record("minus 2 db")
        await peak.record("minus 6 db")
        await peak.record("minus 1 db")
        #expect(await peak.take() == -6)
        #expect(await peak.take() == 0)
    }

    @Test func trackStatusMessagesMatchJXA() {
        let soloed = TrackStatus.Wording(none: "No tracks are soloed.", heading: "Soloed:")
        #expect(TrackStatus.message(names: [], soloed) == "No tracks are soloed.")
        #expect(TrackStatus.message(names: ["Kick - Audio Track ", "Snare - Audio Track "], soloed) == "2 Soloed: Kick - Audio. Snare - Audio. ")
        #expect(TrackStatus.message(names: ["Kick - Audio Track "], .init(none: "", heading: "selected.")) == "1 selected. Kick - Audio. ")
        #expect(TrackStatus.message(names: ["Kick - Audio Track ", "Snare - Audio Track "], TrackStatus.armed) == "2 Armed: Kick - Audio. Snare - Audio. ")
    }

    @Test func chooserTypeSelectFindsTheFirstMatch() {
        let items = ["List Hidden Tracks", "List Input Monitor-Disabled Tracks", "List Muted Tracks"]
        #expect(Chooser.firstMatch("List Hid", in: items) == 0)
        #expect(Chooser.firstMatch("list m", in: items) == 2)
        #expect(Chooser.firstMatch("Hid", in: items) == nil)
    }

    @Test func frozenReportCountsTracksWithoutAFreezeButton() {
        #expect(TrackStatus.frozenText("No shown tracks are frozen.", unreadable: 0) == "No shown tracks are frozen.")
        #expect(TrackStatus.frozenText("2 Frozen: Kick - Inst. Lead Vocal - Audio. ", unreadable: 17) == "2 Frozen: Kick - Inst. Lead Vocal - Audio. Frozen controls not shown in 17 tracks.")
        #expect(TrackStatus.frozenText("Unfroze 1 track.", unreadable: 1) == "Unfroze 1 track. Frozen controls not shown in 1 track.")
    }

    @Test func frozenTrackListingUsesShownTracksAndOffersUnfreeze() throws {
        let listing = try #require(TrackLists.listings.first { $0.name == "List Frozen Tracks" })
        #expect(listing.source == .shownFrozen)
        #expect(listing.heading == "Frozen")
        #expect(listing.prompt == "Choose tracks to unfreeze.")
        #expect(listing.okTitle == "Unfreeze")
        guard case .says(let text) = listing.none else {
            Issue.record("Frozen tracks must use their own empty-list message")
            return
        }
        #expect(text == "No shown tracks are frozen.")
        #expect(text == NoTracks.frozen)
        #expect(SpokenError.text(for: FloError.couldNot(TrackLists.unchangedText(listing, ["Kick - Audio Track "]))) == "Could not unfreeze: Kick - Audio Track.")
    }

    @Test func trackListingsAreDistinct() {
        let listings = TrackLists.listings
        #expect(Set(listings.map(\.name)).count == listings.count)
        #expect(TrackLists.displayName("Kick - Audio Track ") == "Kick - Audio Track")
    }
}

/// `#expect` cannot call mutating methods, so each step's result is stored first.
@Suite struct WindowTitleReadsTests {
    @Test func oneReadAtATime() throws {
        var reads = WindowTitleReads()
        let first = try #require(reads.changeReported() as Int?)
        let pollDuringRead = reads.pollTicked()
        let end = reads.readEnded(id: first)
        let pollAfter = reads.pollTicked()
        #expect(pollDuringRead == nil)
        #expect(end == .publish)
        #expect(pollAfter != nil)
    }

    @Test func changeDuringAReadDropsItAndReadsAgain() throws {
        var reads = WindowTitleReads()
        let first = try #require(reads.changeReported() as Int?)
        let changeDuringRead = reads.changeReported()
        let end = reads.readEnded(id: first)
        #expect(changeDuringRead == nil)
        guard case .readAgain(let second) = end else {
            Issue.record("the stale result was not dropped: \(end)")
            return
        }
        let secondEnd = reads.readEnded(id: second)
        #expect(secondEnd == .publish)
    }

    @Test func pollDuringAReadKeepsItsResult() throws {
        var reads = WindowTitleReads()
        let first = try #require(reads.pollTicked() as Int?)
        let pollDuringRead = reads.pollTicked()
        let end = reads.readEnded(id: first)
        #expect(pollDuringRead == nil)
        #expect(end == .publish)
    }

    @Test func readFromBeforeResetIsIgnored() throws {
        var reads = WindowTitleReads()
        let old = try #require(reads.changeReported() as Int?)
        reads.reset()
        let new = try #require(reads.changeReported() as Int?)
        let oldEnd = reads.readEnded(id: old)
        let newEnd = reads.readEnded(id: new)
        #expect(oldEnd == .ignore)
        #expect(newEnd == .publish)
    }
}

@Suite struct KeyboardFocusTests {
    /// A press goes to the app with keyboard focus only when that is a known app other than the known front app.
    @Test func focusElsewhereOnlyWhenBothKnownAndDifferent() {
        #expect(ContextMonitor.otherFocus(1375, front: 19240) == 1375)
        #expect(ContextMonitor.otherFocus(19240, front: 19240) == nil)
        #expect(ContextMonitor.otherFocus(0, front: 19240) == nil)
        #expect(ContextMonitor.otherFocus(1375, front: 0) == nil)
    }
}

@Suite struct FadeDialogTests {
    /// The JXA read the first "Slope" group for both; the second one belongs to the fade out.
    @Test func outSlopeReadsTheSecondSlopeGroup() {
        let slopes = Dictionary(uniqueKeysWithValues: FadeDialogs.settings.filter { $0.dialog == .batchFades && $0.section.title == "Slope" }.map { ($0.name, $0.section.occurrence) })
        #expect(slopes == ["Next In Slope": 0, "Previous In Slope": 0, "Next Out Slope": 1, "Previous Out Slope": 1])
    }

    /// The Crossfade, Fade In and Fade Out dialogs' Link keys step their one "Slope" group, which the JXA called "Link Out / In" (checked live 2026-11-03).
    @Test(arguments: [(FadeDialog.Kind.crossfade, ["Down", "Up"]), (.fadeIn, ["Opt+Cmd+Down", "Opt+Cmd+Up"]), (.fadeOut, ["Opt+Cmd+Down", "Opt+Cmd+Up"])])
    func linkReadsTheSlopeGroup(dialog: FadeDialog.Kind, keys: [String]) {
        let links = FadeDialogs.settings.filter { $0.dialog == dialog && $0.suffix == ", Link Out/In." }
        #expect(links.map(\.key).sorted() == keys)
        #expect(links.allSatisfy { $0.section == FadeDialog.Section("Slope") })
    }

    /// The named sections are the group titles Pro Tools showed (2026-11-02 and 2026-11-03); only Batch Fades' out slope is a second group.
    @Test func namedSectionsKeepTheirTitles() {
        let sections: [FadeDialog.Section] = [.inShape, .outShape, .slope, .batchOutSlope, .crossfadeLink, .fadeInShape, .fadeOutShape]
        #expect(sections.map(\.title) == ["In Shape", "Out Shape", "Slope", "Slope", "<<- Link ->>", "Fade In Shape", "Fade Out Shape"])
        #expect(sections.map(\.occurrence) == [0, 0, 0, 1, 0, 0, 0])
    }

    /// Batch Fades group titles as Pro Tools showed them on 2026-11-02.
    @Test func batchFadesSectionsExist() {
        let titles: Set = ["Fade In Shape", "Slope", "In Shape", "Out Shape", "<<- Link ->>", "Fade Out Shape"]
        for setting in FadeDialogs.settings where setting.dialog == .batchFades {
            #expect(titles.contains(setting.section.title), "\(setting.id)")
        }
    }

    @Test func spokenSuffixesKeepTheJXAWordingWithTheTypoFixed() {
        let suffixes = Dictionary(uniqueKeysWithValues: FadeDialogs.settings.map { ($0.id, $0.suffix) })
        #expect(suffixes["crossfade.nextCrossfadeInShapeCurve"] == ", Crossfade, In.")
        #expect(suffixes["fadeIn.previousFadeInShapeParameter"] == ", In Shape .")
        #expect(!FadeDialogs.settings.contains { $0.suffix.contains("Crossffade") })
    }
}

@Suite struct CounterTextTests {
    @Test func positionsInBarsAndBeats() {
        #expect(CounterText.spoken("    1| 1| 000", as: .position) == "Bar 1, Beat 1")
        #expect(CounterText.spoken("   12| 3| 240", as: .position) == "Bar 12, Beat 3, Tick 240")
    }

    @Test func durationsInBarsAndBeats() {
        #expect(CounterText.spoken("    0| 0| 000", as: .duration) == "0 ticks")
        #expect(CounterText.spoken("    1| 0| 000", as: .duration) == "1 bar")
        #expect(CounterText.spoken("    0| 0| 480", as: .duration) == "480 ticks")
        #expect(CounterText.spoken("    2| 1| 001", as: .duration) == "2 bars, 1 beat, 1 tick")
    }

    @Test func minutesAndSeconds() {
        #expect(CounterText.spoken("   0:00.000", as: .duration) == "0 seconds")
        #expect(CounterText.spoken("   0:00.250", as: .position) == "250 milliseconds")
        #expect(CounterText.spoken("   1:01.005", as: .duration) == "1 minute, 1 second, 5 milliseconds")
        #expect(CounterText.spoken("  12:30.000", as: .duration) == "12 minutes, 30 seconds")
    }

    @Test func notePitchesLikeJXA() {
        #expect(CounterText.spoken("C3", as: .notePitch) == "C3")
        #expect(CounterText.spoken("C#3", as: .notePitch) == "C-Sharp 3")
        #expect(CounterText.spoken("Fx2", as: .notePitch) == "F-DOUBLE Sharp2")
        #expect(CounterText.spoken("Bb-1", as: .notePitch) == "B-Flat -1")
        #expect(CounterText.spoken("Bbb4", as: .notePitch) == "B-DOUBLE Flat4")
        #expect(CounterText.spoken(" 100", as: .asShown) == "100")
    }

    /// The counter commands and the MIDI event watch take each field's format from here.
    @Test func eachFieldHasItsFormat() {
        #expect([EditWindowControl.mainCounter, .subCounter, .selectionStart, .selectionEnd].map(CounterText.format(of:)) == Array(repeating: .position, count: 4))
        #expect([EditWindowControl.selectionLength, .preRoll, .postRoll, .nudgeValue, .gridValue].map(CounterText.format(of:)) == Array(repeating: .duration, count: 5))
        #expect(CounterText.format(of: .notePitch) == .notePitch)
        #expect([EditWindowControl.attackVelocity, .releaseVelocity, .tempo].map(CounterText.format(of:)) == Array(repeating: .asShown, count: 3))
    }

    @Test func otherFormatsAsShown() {
        #expect(CounterText.spoken(" 00:00:01:12", as: .position) == "00:00:01:12")
        #expect(CounterText.spoken("  48000", as: .duration) == "48000")
    }
}

@Suite struct NoTracksTests {
    /// The JXA's words, shared by the reports, the track lists and the playlist announcement.
    @Test func sentencesAreTheJXAs() {
        #expect([NoTracks.soloed, NoTracks.muted, NoTracks.armed, NoTracks.selected, NoTracks.hidden, NoTracks.shown]
            == ["No tracks are soloed.", "No tracks are muted.", "No tracks are armed.", "No tracks are selected.", "No tracks are hidden.", "No tracks are currently shown."])
    }

    /// Only List Record-Enabled Tracks checks for armed hidden tracks; every other list says its own sentence.
    @Test func onlyTheArmedListChecksHiddenTracks() {
        for listing in TrackLists.listings {
            let checks = if case .armedCheck = listing.none { true } else { false }
            #expect(checks == (listing.name == "List Record-Enabled Tracks"), "\(listing.name)")
        }
    }
}

@Suite struct ReplacingFirstTests {
    @Test func replacesOnlyTheFirstMatch() {
        #expect("a-b-c".replacingFirst("-", with: "+") == "a+b-c")
        #expect("abc".replacingFirst("x", with: "+") == "abc")
        #expect("Track nameKick".replacingFirst("Track name", with: "") == "Kick")
    }
}

@Suite struct ProgressTickerTests {
    @Test func duePastTheIntervalThenWaitsAgain() {
        let start = ContinuousClock.now
        var ticker = ProgressTicker(every: .seconds(1), startingAt: start)
        let due = [500, 1000, 1100, 1900, 2200].map { ticker.isDue(at: start + .milliseconds($0)) }
        #expect(due == [false, false, true, false, true])
    }
}
