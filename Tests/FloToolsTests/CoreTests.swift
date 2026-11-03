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

    @Test func modeConditions() {
        #expect(ModeCondition.inspectorOn.holds(in: Mode(inspector: true)))
        #expect(!ModeCondition.inspectorOn.holds(in: Mode(inspector: false)))
        #expect(ModeCondition.inspectorOff.holds(in: Mode(inspector: false)))
        #expect(ModeCondition.any.holds(in: Mode(inspector: true)))
    }

    /// Two commands may share a key only if one has the higher precedence or they can never apply together.
    @MainActor @Test func tiesAreFound() {
        func command(_ id: CommandID, _ scope: Scope, _ mode: ModeCondition = .any, key: String = "Cmd+1") -> Command {
            Command(id, "Test", scope: scope, mode: mode, triggers: [.key(key)]) { _ in }
        }
        let engine = FloFeatures.makeEngine(commands: [command("test.any", .anyProToolsWindow), command("test.plugIn", .windows([.plugIn])), command("test.inspector", .mixOrEdit, .inspectorOn)])
        #expect(engine.tie(with: command("test.any2", .anyProToolsWindow)) != nil)
        #expect(engine.tie(with: command("test.plugIn2", .windows([.plugIn, .audioSuite]))) != nil)
        #expect(engine.tie(with: command("test.edit", .windows([.edit]))) != nil, "overlaps the Inspector command in Edit, and .any overlaps .inspectorOn")
        #expect(engine.tie(with: command("test.trackView", .mixOrEdit, .inspectorOff)) == nil, "the Inspector is either on or off")
        #expect(engine.tie(with: command("test.audioSuite", .windows([.audioSuite]))) == nil)
        #expect(engine.tie(with: command("test.otherKey", .anyProToolsWindow, key: "Cmd+2")) == nil)
        #expect(engine.tie(with: Command("test.released", "Test", scope: .anyProToolsWindow, triggers: [.key("Cmd+1", .released)]) { _ in }) == nil)
    }
}

@MainActor @Suite struct EngineTests {
    static let proTools = "com.avid.ProTools"
    let mix = FrontContext(bundleID: proTools, windowTitle: "Mix: Session")
    let plugin = FrontContext(bundleID: proTools, windowTitle: "Plug-in: EQ3 7-Band")

    @Test func allCommandsInstall() {
        let engine = FloFeatures.makeEngine()
        #expect(engine.commands.count == FloFeatures.all().count)
        #expect(engine.command("inspector.speakOpenSendB")?.hotKeys.map(\.combo.description) == ["Ctrl+2"])
    }

    @Test func onlyCommandsInMatchingContextAreActive() {
        let engine = FloFeatures.makeEngine(commands: [])
        engine.setInspector(true)
        let ctrl2 = KeyCombo(keyCode: 19, modifiers: KeyCombo.control)
        #expect(engine.activeCombos(in: mix).isEmpty)

        engine.install(Command("test.sendB", "Send B", scope: .mixOrEdit, mode: .inspectorOn, triggers: [.key("Ctrl+2")]) { _ in })
        #expect(engine.activeCombos(in: mix) == [ctrl2])
        #expect(engine.candidates(for: ctrl2, phase: .pressed, in: mix).map(\.id) == ["test.sendB"])
        #expect(engine.candidates(for: ctrl2, phase: .released, in: mix).isEmpty)
        #expect(engine.activeCombos(in: plugin).isEmpty)

        engine.setCommand("test.sendB", enabled: false)
        #expect(engine.activeCombos(in: mix).isEmpty)
    }

    @Test func windowScopeWinsOverAnyWindow() {
        // Cmd+1 is "Tab 1" in setup windows, "Assign Insert A" in the Inspector and "Load Plugin Parameters for View 1" in plug-in windows; here an any-window binding stands in for a general key.
        let engine = FloFeatures.makeEngine(commands: [])
        engine.setInspector(true)
        for (id, scope, mode) in [("test.any", Scope.anyProToolsWindow, ModeCondition.any), ("test.inspector", .mixOrEdit, .inspectorOn), ("test.plugIn", .windows([.plugIn]), .any)] {
            engine.install(Command(CommandID(id), "Cmd+1", scope: scope, mode: mode, triggers: [.key("Cmd+1")]) { _ in })
        }
        let cmd1 = KeyCombo(keyCode: 18, modifiers: KeyCombo.command)
        #expect(engine.candidates(for: cmd1, phase: .pressed, in: plugin).first?.id == "test.plugIn")
        #expect(engine.candidates(for: cmd1, phase: .pressed, in: mix).first?.id == "test.inspector")
        engine.setInspector(false)
        #expect(engine.candidates(for: cmd1, phase: .pressed, in: mix).map(\.id) == ["test.any"])
    }

    @Test func inspectorModeGatesKeys() {
        let engine = FloFeatures.makeEngine(commands: [])
        engine.install(Command("test.solo", "Solo", scope: .mixOrEdit, mode: .inspectorOn, triggers: [.key("S")]) { _ in })
        let s = KeyCombo("S")!
        #expect(engine.activeCombos(in: mix).isEmpty, "the Inspector starts off")
        engine.setInspector(true)
        #expect(engine.activeCombos(in: mix) == [s])
        engine.setInspector(false)
        #expect(engine.activeCombos(in: mix).isEmpty)
    }

    @Test func inspectorSwapsCtrlCmdArrowsWithTrackView() {
        let engine = FloFeatures.makeEngine()
        let right = KeyCombo("Ctrl+Cmd+Right")!
        let edit = FrontContext(bundleID: Self.proTools, windowTitle: "Edit: Session")
        #expect(engine.candidates(for: right, phase: .pressed, in: edit).map(\.id) == [InspectorMode.nextTrackView])
        #expect(engine.candidates(for: KeyCombo("S")!, phase: .pressed, in: edit).isEmpty)
        engine.setInspector(true)
        #expect(engine.candidates(for: right, phase: .pressed, in: edit).map(\.id) == ["inspector.panRightOnMonoLeftChannel"])
        #expect(engine.candidates(for: KeyCombo("S")!, phase: .pressed, in: edit).map(\.id) == ["inspector.speakToggleSolo"])
    }

    @Test func preferencesControlInspectorCommands() {
        let engine = FloFeatures.makeEngine()
        var preferences = Preferences()
        FloFeatures.apply(preferences, to: engine)
        FloFeatures.setStartState(preferences, in: engine)
        #expect(!engine.isCommandEnabled(InspectorMode.toggleTemporaryInspector))
        #expect(!engine.mode.inspector)
        preferences.temporaryInspector = true
        preferences.startsWithInspector = true
        FloFeatures.apply(preferences, to: engine)
        FloFeatures.setStartState(preferences, in: engine)
        #expect(engine.isCommandEnabled(InspectorMode.toggleTemporaryInspector))
        #expect(engine.mode.inspector)
    }
}

@MainActor @Suite struct MonitorsTests {
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
        let monitors = Watches()
        let probe = Probe()
        var events = probe.events.makeAsyncIterator()
        #expect(monitors.toggle("inspector.a", probe.body))
        #expect(await events.next() == "started")
        #expect(monitors.isRunning("inspector.a"))
        #expect(!monitors.toggle("inspector.a", probe.body))
        #expect(await events.next() == "ended")
        #expect(!monitors.isRunning("inspector.a"))
    }

    @Test func aStoppedWatchEndingLateDoesNotForgetItsReplacement() async {
        let monitors = Watches()
        let first = Probe(), second = Probe()
        var firstEvents = first.events.makeAsyncIterator(), secondEvents = second.events.makeAsyncIterator()
        monitors.toggle("inspector.a", first.body)
        #expect(await firstEvents.next() == "started")
        monitors.toggle("inspector.a", first.body)
        monitors.toggle("inspector.a", second.body)
        #expect(await firstEvents.next() == "ended")
        #expect(await secondEvents.next() == "started")
        await Task.yield()
        #expect(monitors.isRunning("inspector.a"))
        monitors.stopAll()
        #expect(await secondEvents.next() == "ended")
        #expect(!monitors.isRunning("inspector.a"))
    }

    @Test func aWatchThatEndsByItselfIsForgotten() async {
        let monitors = Watches()
        let (ended, continuation) = AsyncStream<Void>.makeStream()
        monitors.toggle("inspector.a") { continuation.yield() }
        var iterator = ended.makeAsyncIterator()
        _ = await iterator.next()
        while monitors.isRunning("inspector.a") { await Task.yield() }
        #expect(!monitors.isRunning("inspector.a"))
    }
}

@Suite struct DoublePressDeciderTests {
    let start = ContinuousClock.now

    @Test func secondPressInTimeIsDouble() {
        var decider = DoublePressDecider(timeout: .milliseconds(200))
        let first = decider.press("a", at: start)
        let second = decider.press("a", at: start + .milliseconds(150))
        // The voided single does not run when its timer ends.
        let voidedSingleRuns = decider.singleIsDue("a", generation: 1)
        #expect(first == .single(generation: 1))
        #expect(second == .double)
        #expect(!voidedSingleRuns)
    }

    @Test func lateSecondPressIsANewSingle() {
        var decider = DoublePressDecider(timeout: .milliseconds(200))
        _ = decider.press("a", at: start)
        let second = decider.press("a", at: start + .milliseconds(250))
        let firstRuns = decider.singleIsDue("a", generation: 1)
        let secondRuns = decider.singleIsDue("a", generation: 2)
        let secondRunsAgain = decider.singleIsDue("a", generation: 2)
        #expect(second == .single(generation: 2))
        #expect(!firstRuns)
        #expect(secondRuns)
        #expect(!secondRunsAgain)
    }

    @Test func differentCommandsDoNotCombine() {
        var decider = DoublePressDecider(timeout: .milliseconds(200))
        _ = decider.press("a", at: start)
        let other = decider.press("b", at: start + .milliseconds(10))
        let firstRuns = decider.singleIsDue("a", generation: 1)
        #expect(other == .single(generation: 2))
        #expect(firstRuns)
    }

    @Test func cancelAllVoidsPendingSingles() {
        var decider = DoublePressDecider(timeout: .milliseconds(200))
        _ = decider.press("a", at: start)
        decider.cancelAll()
        let cancelledRuns = decider.singleIsDue("a", generation: 1)
        let next = decider.press("a", at: start + .milliseconds(10))
        #expect(!cancelledRuns)
        #expect(next == .single(generation: 2))
    }
}

/// Runs commands through the engine without hotkeys: `dispatch` is what a hotkey press calls after reading the context.
@MainActor @Suite struct CommandRunTests {
    let mix = FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Mix: Session")

    @MainActor final class Events {
        var list: [String] = []
    }

    func engine(_ commands: [Command]) -> Engine {
        let engine = FloFeatures.makeEngine(commands: commands)
        engine.doublePressTimeout = .milliseconds(50)
        return engine
    }

    func doubleCommand(_ events: Events) -> Command {
        Command("test.speak", "Speak", scope: .anyProToolsWindow, triggers: [.key("F1")], single: { @MainActor _ in events.list.append("single") }, double: { @MainActor _ in events.list.append("double") })
    }

    @Test func singlePressRunsAfterTimeout() async throws {
        let events = Events()
        let engine = engine([doubleCommand(events)])
        #expect(engine.dispatch(KeyCombo("F1")!, .pressed, in: mix) != nil)
        #expect(events.list.isEmpty)
        await engine.waitUntilIdle()
        #expect(events.list == ["single"])
    }

    @Test func secondPressInTimeRunsDoubleOnly() async throws {
        let events = Events()
        let engine = engine([doubleCommand(events)])
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        await engine.waitUntilIdle()
        #expect(events.list == ["double"])
    }

    @Test func disablingACommandVoidsPendingSingles() async throws {
        let events = Events()
        let engine = engine([doubleCommand(events), Command("test.other", "Other", scope: .anyProToolsWindow, triggers: []) { @MainActor _ in }])
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        engine.setCommand("test.other", enabled: false)
        await engine.waitUntilIdle()
        #expect(events.list.isEmpty)
    }

    @Test func topLevelRunsDoNotInterleave() async throws {
        let events = Events()
        let engine = engine([
            Command("test.slow", "Slow", scope: .anyProToolsWindow, triggers: [.key("F1")]) { @MainActor _ in
                events.list.append("slow start")
                try await Task.sleep(for: .milliseconds(50))
                events.list.append("slow end")
            },
            Command("test.fast", "Fast", scope: .anyProToolsWindow, triggers: [.key("F2")]) { @MainActor _ in events.list.append("fast") },
        ])
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
        engine.setCommand("test.fast", enabled: false)
        await engine.waitUntilIdle()
        #expect(events.list == ["slow start", "slow end"])
    }

    /// A track view press queued while the Inspector was off must not run after `/` turned it on, because its key now pans.
    @Test func queuedInspectorOffRunIsDroppedWhenTheInspectorTurnsOn() async throws {
        let events = Events()
        var commands = slowThenFast(events)
        commands[1] = Command("test.trackView", "Track View", scope: .anyProToolsWindow, mode: .inspectorOff, triggers: [.key("F2")]) { @MainActor _ in events.list.append("track view") }
        let engine = engine(commands)
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        engine.dispatch(KeyCombo("F2")!, .pressed, in: mix)
        engine.setInspector(true)
        await engine.waitUntilIdle()
        #expect(events.list == ["slow start", "slow end"])
    }

    @Test func queuedRunIsDroppedWhenAnotherAppIsInFront() async throws {
        let events = Events()
        var signalStarted: AsyncStream<Void>.Continuation?
        let started = AsyncStream<Void> { signalStarted = $0 }
        var signalFinish: AsyncStream<Void>.Continuation?
        let finish = AsyncStream<Void> { signalFinish = $0 }
        let engine = engine([
            Command("test.slow", "Slow", scope: .anyProToolsWindow, triggers: [.key("F1")]) { @MainActor [signalStarted] _ in
                signalStarted?.yield()
                for await _ in finish { break }
                events.list.append("slow")
            },
            Command("test.fast", "Fast", scope: .anyProToolsWindow, triggers: [.key("F2")]) { @MainActor _ in events.list.append("fast") },
        ])
        let proTools = FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Mix: Session", processID: 100)
        engine.dispatch(KeyCombo("F1")!, .pressed, in: proTools)
        engine.dispatch(KeyCombo("F2")!, .pressed, in: proTools)
        for await _ in started { break }
        // While the slow command runs, Finder comes to front and a key no command takes is pressed.
        #expect(engine.dispatch(KeyCombo("F9")!, .pressed, in: FrontContext(bundleID: "com.apple.finder", processID: 200)) == nil)
        signalFinish?.yield()
        await engine.waitUntilIdle()
        #expect(events.list == ["slow"])
    }

    func holdCommand(_ events: Events, accepts: Bool = true) -> Command {
        Command("test.hold", "Hold", scope: .anyProToolsWindow, triggers: [.key("F3"), .key("F3", .released)], press: { _ in
            events.list.append("press")
            return accepts
        }, release: { _ in
            events.list.append("release")
        })
    }

    @Test func holdEndsOnReleaseWithoutTheQueue() async throws {
        let events = Events()
        let engine = engine(slowThenFast(events) + [holdCommand(events)])
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        engine.dispatch(KeyCombo("F3")!, .pressed, in: mix)
        engine.dispatch(KeyCombo("F3")!, .released, in: mix)
        // Both ran at once, before the queued slow command started.
        #expect(events.list == ["press", "release"])
        await engine.waitUntilIdle()
        engine.dispatch(KeyCombo("F3")!, .released, in: mix)
        #expect(events.list == ["press", "release", "slow start", "slow end"])
    }

    @Test func declinedHoldGetsNoRelease() {
        let events = Events()
        let engine = engine([holdCommand(events, accepts: false)])
        engine.dispatch(KeyCombo("F3")!, .pressed, in: mix)
        engine.dispatch(KeyCombo("F3")!, .released, in: mix)
        #expect(events.list == ["press"])
    }

    @Test func inspectorSingleStillRunsAfterTheTemporaryHoldEnds() async throws {
        let events = Events()
        let engine = engine(InspectorMode.commands + [
            Command("test.inspectorKey", "Inspector key", scope: .mixOrEdit, mode: .inspectorOn, triggers: [.key("F1")], single: { @MainActor _ in events.list.append("single") }, double: { @MainActor _ in events.list.append("double") }),
        ])
        #expect(engine.dispatch(KeyCombo("`")!, .pressed, in: mix) != nil)
        #expect(engine.mode.inspector)
        #expect(engine.dispatch(KeyCombo("F1")!, .pressed, in: mix) != nil)
        // Released within the double-press timeout: the accepted single press must still run.
        engine.dispatch(KeyCombo("`")!, .released, in: mix)
        #expect(!engine.mode.inspector)
        await engine.waitUntilIdle()
        #expect(events.list == ["single"])
    }

    /// With the Inspector off, Ctrl+Cmd+Right is Pro Tools' track view key; while the temporary Inspector is held it pans, and after release it is the track view key again.
    @Test func temporaryInspectorHoldPansWithCtrlCmdArrows() {
        let engine = engine(InspectorMode.commands + Inspector.commands)
        let right = KeyCombo("Ctrl+Cmd+Right")!
        #expect(engine.candidates(for: right, phase: .pressed, in: mix).map(\.id) == [InspectorMode.nextTrackView])
        #expect(engine.dispatch(KeyCombo("`")!, .pressed, in: mix) != nil)
        #expect(engine.candidates(for: right, phase: .pressed, in: mix).map(\.id) == ["inspector.panRightOnMonoLeftChannel"])
        engine.dispatch(KeyCombo("`")!, .released, in: mix)
        #expect(engine.candidates(for: right, phase: .pressed, in: mix).map(\.id) == [InspectorMode.nextTrackView])
    }

    /// A held key that stops being a hotkey never reports its release, so the engine ends the hold itself: when Flo Tools is suspended or turned off, when the command is turned off, and when the front window is one where the key does not apply. The temporary Inspector then turns off.
    @Test(arguments: ["suspended", "disabled", "command turned off", "window changed"])
    func temporaryInspectorEndsWhenItsKeyStopsBeingAHotkey(_ cause: String) {
        let engine = engine(InspectorMode.commands)
        engine.dispatch(KeyCombo("`")!, .pressed, in: mix)
        #expect(engine.mode.inspector)
        switch cause {
        case "suspended": engine.suspend(Suspension("test"))
        case "disabled": engine.isEnabled = false
        case "command turned off": engine.setCommand(InspectorMode.toggleTemporaryInspector, enabled: false)
        default: engine.contextChanged(to: FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Memory Locations"))
        }
        #expect(!engine.mode.inspector)
    }

    @Test func holdOutlivesChangesThatKeepItsKey() {
        let events = Events()
        let engine = engine([holdCommand(events)])
        engine.dispatch(KeyCombo("F3")!, .pressed, in: mix)
        engine.contextChanged(to: FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Edit: Session"))
        #expect(events.list == ["press"])
        engine.dispatch(KeyCombo("F3")!, .released, in: mix)
        #expect(events.list == ["press", "release"])
    }

    @Test func stopEndsHolds() {
        let events = Events()
        let engine = engine([holdCommand(events)])
        engine.dispatch(KeyCombo("F3")!, .pressed, in: mix)
        engine.stop()
        engine.dispatch(KeyCombo("F3")!, .released, in: mix)
        #expect(events.list == ["press", "release"])
    }

    @Test func stopCancelsARunningCommand() async throws {
        let events = Events()
        var signalStarted: AsyncStream<Void>.Continuation?
        let started = AsyncStream<Void> { signalStarted = $0 }
        let engine = engine([
            Command("test.long", "Long", scope: .anyProToolsWindow, triggers: [.key("F1")]) { @MainActor [signalStarted] _ in
                signalStarted?.yield()
                do {
                    try await Task.sleep(for: .seconds(5))
                    events.list.append("finished")
                } catch {
                    events.list.append("cancelled")
                }
            },
        ])
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
        var signalStarted: AsyncStream<Void>.Continuation?
        let started = AsyncStream<Void> { signalStarted = $0 }
        let engine = engine([
            Command("test.long", "Long", scope: .anyProToolsWindow, triggers: [.key("F1")]) { @MainActor [signalStarted] _ in
                signalStarted?.yield()
                do {
                    try await Task.sleep(for: .seconds(5))
                    events.list.append("finished")
                } catch {
                    events.list.append("cancelled")
                }
            },
            Command("test.short", "Short", scope: .anyProToolsWindow, triggers: [.key("F2")]) { @MainActor _ in events.list.append("short") },
        ])
        engine.monitors.toggle("test.watch") { try? await Task.sleep(for: .seconds(5)) }
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        for await _ in started { break }
        engine.cancelAll()
        await engine.waitUntilIdle()
        #expect(!engine.monitors.isRunning("test.watch"))
        engine.dispatch(KeyCombo("F2")!, .pressed, in: mix)
        await engine.waitUntilIdle()
        #expect(events.list == ["cancelled", "short"])
    }

    @Test func cancelAllEndsAfterTheCancelledWorkHasEnded() async {
        let events = Events()
        var signalStarted: AsyncStream<Void>.Continuation?
        let started = AsyncStream<Void> { signalStarted = $0 }
        let engine = engine([
            Command("test.long", "Long", scope: .anyProToolsWindow, triggers: [.key("F1")]) { @MainActor [signalStarted] _ in
                signalStarted?.yield()
                try? await Task.sleep(for: .seconds(5))
                // Work a run does after it was cancelled, like writing remembered state, still comes before the end of cancelAll.
                await Task.yield()
                events.list.append("run wrote")
            },
        ])
        engine.monitors.toggle("test.watch") { @MainActor in
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
        let plugIn = FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Plug-in: EQ3 7-Band")
        #expect(engine.statusMenuCommands(in: plugIn).map(\.id) == ["plugin.displayPluginViewTemplate"])
        #expect(engine.statusMenuCommands(in: FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Mix: Session")).isEmpty)
        engine.isEnabled = false
        #expect(engine.statusMenuCommands(in: plugIn).isEmpty)
    }

    @Test func doneSoundTimingMatchesJXA() throws {
        func doneSound(_ id: CommandID) throws -> DoneSoundTiming? {
            let command = try #require(FloFeatures.all().first { $0.id == id })
            guard case .singleOrDouble(_, _, let doneSound) = command.action else { return nil }
            return doneSound
        }
        #expect(try doneSound("inspector.speakOpenSendB") == .afterDouble)
        #expect(try doneSound("inspector.speakToggleSolo") == .afterDouble)
        #expect(try doneSound("floTools.speakSoloedTracksUnsoloAllTracks") == .beforeDouble)
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
}

@MainActor @Suite struct VoiceOverTests {
    @Test func failureReasons() {
        #expect(VoiceOver.failureReason(status: -600) == "VoiceOver is not running")
        #expect(VoiceOver.failureReason(status: -1712) == "VoiceOver did not answer within 2 seconds")
        #expect(VoiceOver.failureReason(status: -1743) == "Flo Tools may not control VoiceOver (Automation permission)")
        #expect(VoiceOver.failureReason(status: -1708) == "Apple event error -1708")
    }
}

@Suite @MainActor struct PreferencesTests {
    /// A throwaway suite, so tests never touch the user's settings.
    private func makeDefaults() -> UserDefaults {
        let name = "FloToolsTests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func missingValuesAreDefaults() {
        #expect(PreferencesStore(defaults: makeDefaults()).current == Preferences())
    }

    @Test func savedPreferencesAreReadBack() {
        let defaults = makeDefaults()
        var preferences = Preferences()
        preferences.temporaryInspector = true
        preferences.startsWithInspector = true
        preferences.timeout = 400
        PreferencesStore(defaults: defaults).save(preferences)
        #expect(PreferencesStore(defaults: defaults).current == preferences)
    }

    /// The user's off switch survives a relaunch; a first launch starts enabled.
    @Test func floToolsEnabledIsRemembered() {
        let defaults = makeDefaults()
        #expect(PreferencesStore(defaults: defaults).floToolsEnabled)
        PreferencesStore(defaults: defaults).floToolsEnabled = false
        #expect(!PreferencesStore(defaults: defaults).floToolsEnabled)
    }

    @Test func unsupportedTimeoutFallsBackToDefault() {
        let defaults = makeDefaults()
        defaults.set(50, forKey: PreferencesStore.Key.timeout)
        #expect(PreferencesStore(defaults: defaults).current.timeout == 200)
    }

    @Test func applySetsDoublePressTimeout() {
        let engine = FloFeatures.makeEngine()
        var preferences = Preferences()
        preferences.timeout = 500
        FloFeatures.apply(preferences, to: engine)
        #expect(engine.doublePressTimeout == .milliseconds(500))
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

    @Test func slotMessageMatchesJXA() {
        #expect(Inspector.slotMessage(.send, selectorName: "Send selector B", selectorValue: "unassigned", assignmentValue: "unassigned") == " B. : unassigned")
        #expect(Inspector.slotMessage(.send, selectorName: "Send selector B", selectorValue: "Bus 1", assignmentValue: "Send Assignment Reverb") == " B. Bus 1: Reverb")
        // Values seen on Kick on 2026-11-02.
        #expect(Inspector.slotMessage(.insert, selectorName: "Insert selector A", selectorValue: "inactive", assignmentValue: "SSL Native Channelstrip v6") == " A. inactive: SSL Native Channelstrip v6")
        #expect(Inspector.slotMessage(.insert, selectorName: "Insert selector B", selectorValue: "unassigned", assignmentValue: "unassigned") == " B. : unassigned")
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
        func state(_ flag: TrackFlag, _ name: String, _ value: String) -> Bool? { TrackFlag.state(of: flag, trackName: name, buttonState: value) }
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

    @Test func trackListRowNames() {
        #expect(TrackList.trackName(selectButtonName: "Selected. Open. Drums - Routing Folder Track ") == "Drums - Routing Folder Track ")
        #expect(TrackList.trackName(selectButtonName: "Closed. Drums - Routing Folder Track ") == "Drums - Routing Folder Track ")
        #expect(TrackList.trackName(selectButtonName: "Kick - Audio Track ") == "Kick - Audio Track ")
        #expect(TrackList.isSelected(selectButtonName: "Selected. Kick - Audio Track "))
        #expect(!TrackList.isSelected(selectButtonName: "Kick - Audio Track "))
    }

    @Test func peakText() {
        #expect(TrackStrip.decibels(peakText: "minus 3.1") == -3.1)
        #expect(TrackStrip.decibels(peakText: "3.0") == 3.0)
        #expect(TrackStrip.decibels(peakText: "0.0") == 0)
        #expect(TrackStrip.decibels(peakText: "minus ∞") == nil)
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
        #expect(InspectorControls.panList(["100 to the left", "100 to the right"]) == "100 to the left. 100 to the right. ")
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
    }

    @Test func chooserTypeSelectFindsTheFirstMatch() {
        let items = ["List Hidden Tracks", "List Input Monitor-Disabled  Tracks", "List Muted Tracks"]
        #expect(Chooser.firstMatch("List Hid", in: items) == 0)
        #expect(Chooser.firstMatch("list m", in: items) == 2)
        #expect(Chooser.firstMatch("Hid", in: items) == nil)
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

@Suite struct FadeDialogTests {
    /// The JXA read the first "Slope" group for both; the second one belongs to the fade out.
    @Test func outSlopeReadsTheSecondSlopeGroup() {
        let slopes = Dictionary(uniqueKeysWithValues: FadeDialogs.settings.filter { $0.section.title == "Slope" }.map { ($0.name, $0.section.occurrence) })
        #expect(slopes == ["Next In Slope": 0, "Previous In Slope": 0, "Next Out Slope": 1, "Previous Out Slope": 1])
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

    @Test func otherFormatsAsShown() {
        #expect(CounterText.spoken(" 00:00:01:12", as: .position) == "00:00:01:12")
        #expect(CounterText.spoken("  48000", as: .duration) == "48000")
    }
}
