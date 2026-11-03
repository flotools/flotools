import ApplicationServices
import Foundation
import Testing
@testable import FloMacros
@testable import FloEngine
@testable import FloProTools
@testable import FloSystem

@Suite struct GroupTests {
    @Test func groupConditions() throws {
        let inspector = try #require(FloMacros.groups.first { $0.id == .inspector })
        #expect(inspector.applies(to: FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Mix: I Trust")))
        #expect(inspector.applies(to: FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Edit: I Trust")))
        #expect(!inspector.applies(to: FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Plug-in: EQ3")))
        #expect(!inspector.applies(to: FrontContext(bundleID: "com.apple.finder", windowTitle: "Mix: I Trust")))

        let fadeIn = try #require(FloMacros.groups.first { $0.id == .fadeIn })
        #expect(fadeIn.applies(to: FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Fade In")))
        #expect(!fadeIn.applies(to: FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Fade In Out")))

        let global = try #require(FloMacros.groups.first { $0.id == .global })
        #expect(global.applies(to: FrontContext(bundleID: "com.apple.finder")))
    }
}

@MainActor @Suite struct EngineTests {
    static let proTools = "com.avid.ProTools"
    let mix = FrontContext(bundleID: proTools, windowTitle: "Mix: Session")
    let plugin = FrontContext(bundleID: proTools, windowTitle: "Plug-in: EQ3 7-Band")

    @Test func allMacrosInstall() {
        let engine = FloMacros.makeEngine()
        #expect(engine.macros.count == FloMacros.all.count)
        #expect(engine.macro("inspector.speakOpenSendB")?.hotKeys.map(\.combo.description) == ["Ctrl+2"])
    }

    @Test func onlyMacrosInMatchingContextAreActive() {
        let engine = FloMacros.makeEngine(macros: [])
        let ctrl2 = KeyCombo(keyCode: 19, modifiers: KeyCombo.control)
        #expect(engine.activeCombos(in: mix).isEmpty)

        engine.install(Macro("test.sendB", "Send B", group: .inspector, triggers: [.key("Ctrl+2")]) { _ in })
        #expect(engine.activeCombos(in: mix) == [ctrl2])
        #expect(engine.candidates(for: ctrl2, phase: .pressed, in: mix).map(\.id) == ["test.sendB"])
        #expect(engine.candidates(for: ctrl2, phase: .released, in: mix).isEmpty)
        #expect(engine.activeCombos(in: plugin).isEmpty)

        engine.setGroup(.inspector, enabled: false)
        #expect(engine.activeCombos(in: mix).isEmpty)
        engine.setGroup(.inspector, enabled: true)
        engine.setMacro("test.sendB", enabled: false)
        #expect(engine.activeCombos(in: mix).isEmpty)
    }

    @Test func windowSpecificGroupWinsOverAppGroup() {
        // In KM, Cmd+1 is "Tab 1" in Selected Tab, "Assign Insert A" in Inspector and "Load Plugin Parameters for View 1" in Plugin.
        let engine = FloMacros.makeEngine(macros: [])
        for group in [MacroGroupID.floTools, .inspector, .plugin] {
            engine.install(Macro(MacroID("test.\(group)"), "Cmd+1", group: group, triggers: [.key("Cmd+1")]) { _ in })
        }
        let cmd1 = KeyCombo(keyCode: 18, modifiers: KeyCombo.command)
        #expect(engine.candidates(for: cmd1, phase: .pressed, in: plugin).first?.group == .plugin)
        #expect(engine.candidates(for: cmd1, phase: .pressed, in: mix).first?.group == .inspector)
    }

    @Test func deactivatedGroupTakesNoKeys() {
        let engine = FloMacros.makeEngine(macros: [])
        engine.install(Macro("test.solo", "Solo", group: .inspector, triggers: [.key("S")]) { _ in })
        let s = KeyCombo("S")!
        engine.setGroup(.inspector, activated: false)
        #expect(engine.activeCombos(in: mix).isEmpty)
        #expect(engine.isGroupEnabled(.inspector))
        engine.setGroup(.inspector, activated: true)
        #expect(engine.activeCombos(in: mix) == [s])
        // Disabling and re-enabling the group does not activate it.
        engine.setGroup(.inspector, activated: false)
        engine.setGroup(.inspector, enabled: false)
        engine.setGroup(.inspector, enabled: true)
        #expect(engine.activeCombos(in: mix).isEmpty)
    }

    @Test func inspectorSwapsCtrlCmdArrowsWithTrackView() {
        let engine = FloMacros.makeEngine()
        let right = KeyCombo("Ctrl+Cmd+Right")!
        let edit = FrontContext(bundleID: Self.proTools, windowTitle: "Edit: Session")
        #expect(!engine.isMacroEnabled(InspectorMode.nextTrackView))
        InspectorMode.setInspector(false, in: engine)
        #expect(!engine.isGroupActivated(.inspector))
        #expect(engine.candidates(for: right, phase: .pressed, in: edit).map(\.id) == [InspectorMode.nextTrackView])
        #expect(engine.candidates(for: KeyCombo("S")!, phase: .pressed, in: edit).isEmpty)
        InspectorMode.setInspector(true, in: engine)
        #expect(engine.candidates(for: right, phase: .pressed, in: edit).isEmpty)
        #expect(engine.candidates(for: KeyCombo("S")!, phase: .pressed, in: edit).map(\.id) == ["inspector.speakToggleSolo"])
    }

    @Test func preferencesControlInspectorMacros() {
        let engine = FloMacros.makeEngine()
        var preferences = Preferences()
        FloMacros.apply(preferences, to: engine)
        FloMacros.setStartState(preferences, in: engine)
        #expect(!engine.isMacroEnabled(InspectorMode.toggleTemporaryInspector))
        #expect(!engine.isGroupActivated(.inspector))
        preferences.temporaryInspector = true
        preferences.startsWithInspector = true
        FloMacros.apply(preferences, to: engine)
        FloMacros.setStartState(preferences, in: engine)
        #expect(engine.isMacroEnabled(InspectorMode.toggleTemporaryInspector))
        #expect(engine.isGroupActivated(.inspector))
    }

    @Test func toggleInspectorWindowCondition() {
        #expect(InspectorMode.mixOrEdit.matches("Mix: Session"))
        #expect(InspectorMode.mixOrEdit.matches("Edit: Session"))
        #expect(!InspectorMode.mixOrEdit.matches("Plug-in: EQ3"))
        #expect(!InspectorMode.mixOrEdit.matches(nil))
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

    @Test func differentMacrosDoNotCombine() {
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

/// Runs macros through the engine without hotkeys: `dispatch` is what a hotkey press calls after reading the context.
@MainActor @Suite struct MacroRunTests {
    let mix = FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Mix: Session")

    @MainActor final class Events {
        var list: [String] = []
    }

    func engine(_ macros: [Macro]) -> MacroEngine {
        let engine = FloMacros.makeEngine(macros: macros)
        engine.doublePressTimeout = .milliseconds(50)
        return engine
    }

    func doubleMacro(_ events: Events) -> Macro {
        Macro("test.speak", "Speak", group: .floTools, triggers: [.key("F1")], single: { @MainActor _ in events.list.append("single") }, double: { @MainActor _ in events.list.append("double") })
    }

    @Test func singlePressRunsAfterTimeout() async throws {
        let events = Events()
        let engine = engine([doubleMacro(events)])
        #expect(engine.dispatch(KeyCombo("F1")!, .pressed, in: mix) != nil)
        #expect(events.list.isEmpty)
        await engine.waitUntilIdle()
        #expect(events.list == ["single"])
    }

    @Test func secondPressInTimeRunsDoubleOnly() async throws {
        let events = Events()
        let engine = engine([doubleMacro(events)])
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        await engine.waitUntilIdle()
        #expect(events.list == ["double"])
    }

    @Test func disablingAMacroVoidsPendingSingles() async throws {
        let events = Events()
        let engine = engine([doubleMacro(events), Macro("test.other", "Other", group: .floTools, triggers: []) { @MainActor _ in }])
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        engine.setMacro("test.other", enabled: false)
        await engine.waitUntilIdle()
        #expect(events.list.isEmpty)
    }

    @Test func topLevelRunsDoNotInterleave() async throws {
        let events = Events()
        let engine = engine([
            Macro("test.slow", "Slow", group: .floTools, triggers: [.key("F1")]) { @MainActor _ in
                events.list.append("slow start")
                try await Task.sleep(for: .milliseconds(50))
                events.list.append("slow end")
            },
            Macro("test.fast", "Fast", group: .floTools, triggers: [.key("F2")]) { @MainActor _ in events.list.append("fast") },
        ])
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        engine.dispatch(KeyCombo("F2")!, .pressed, in: mix)
        await engine.waitUntilIdle()
        #expect(events.list == ["slow start", "slow end", "fast"])
    }

    func slowThenFast(_ events: Events) -> [Macro] {
        [
            Macro("test.slow", "Slow", group: .floTools, triggers: [.key("F1")]) { @MainActor _ in
                events.list.append("slow start")
                try await Task.sleep(for: .milliseconds(50))
                events.list.append("slow end")
            },
            Macro("test.fast", "Fast", group: .floTools, triggers: [.key("F2")]) { @MainActor _ in events.list.append("fast") },
        ]
    }

    @Test func queuedRunIsDroppedWhenItsMacroIsDisabled() async throws {
        let events = Events()
        let engine = engine(slowThenFast(events))
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        engine.dispatch(KeyCombo("F2")!, .pressed, in: mix)
        engine.setMacro("test.fast", enabled: false)
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
            Macro("test.slow", "Slow", group: .floTools, triggers: [.key("F1")]) { @MainActor [signalStarted] _ in
                signalStarted?.yield()
                for await _ in finish { break }
                events.list.append("slow")
            },
            Macro("test.fast", "Fast", group: .floTools, triggers: [.key("F2")]) { @MainActor _ in events.list.append("fast") },
        ])
        let proTools = FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Mix: Session", processID: 100)
        engine.dispatch(KeyCombo("F1")!, .pressed, in: proTools)
        engine.dispatch(KeyCombo("F2")!, .pressed, in: proTools)
        for await _ in started { break }
        // While the slow macro runs, Finder comes to front and a key no macro takes is pressed.
        #expect(engine.dispatch(KeyCombo("F9")!, .pressed, in: FrontContext(bundleID: "com.apple.finder", processID: 200)) == nil)
        signalFinish?.yield()
        await engine.waitUntilIdle()
        #expect(events.list == ["slow"])
    }

    func holdMacro(_ events: Events, accepts: Bool = true) -> Macro {
        Macro("test.hold", "Hold", group: .floTools, triggers: [.key("F3"), .key("F3", .released)], press: { _ in
            events.list.append("press")
            return accepts
        }, release: { _ in
            events.list.append("release")
        })
    }

    @Test func holdEndsOnReleaseWithoutTheQueue() async throws {
        let events = Events()
        let engine = engine(slowThenFast(events) + [holdMacro(events)])
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        engine.dispatch(KeyCombo("F3")!, .pressed, in: mix)
        engine.dispatch(KeyCombo("F3")!, .released, in: mix)
        // Both ran at once, before the queued slow macro started.
        #expect(events.list == ["press", "release"])
        await engine.waitUntilIdle()
        engine.dispatch(KeyCombo("F3")!, .released, in: mix)
        #expect(events.list == ["press", "release", "slow start", "slow end"])
    }

    @Test func declinedHoldGetsNoRelease() {
        let events = Events()
        let engine = engine([holdMacro(events, accepts: false)])
        engine.dispatch(KeyCombo("F3")!, .pressed, in: mix)
        engine.dispatch(KeyCombo("F3")!, .released, in: mix)
        #expect(events.list == ["press"])
    }

    @Test func inspectorSingleStillRunsAfterTheTemporaryHoldEnds() async throws {
        let events = Events()
        let engine = engine(InspectorMode.macros + [
            Macro("test.inspectorKey", "Inspector key", group: .inspector, triggers: [.key("F1")], single: { @MainActor _ in events.list.append("single") }, double: { @MainActor _ in events.list.append("double") }),
        ])
        engine.setGroup(.inspector, activated: false)
        #expect(engine.dispatch(KeyCombo("`")!, .pressed, in: mix) != nil)
        #expect(engine.isGroupActivated(.inspector))
        #expect(engine.dispatch(KeyCombo("F1")!, .pressed, in: mix) != nil)
        // Released within the double-press timeout: the accepted single press must still run.
        engine.dispatch(KeyCombo("`")!, .released, in: mix)
        #expect(!engine.isGroupActivated(.inspector))
        await engine.waitUntilIdle()
        #expect(events.list == ["single"])
    }

    @Test func stopEndsHolds() {
        let events = Events()
        let engine = engine([holdMacro(events)])
        engine.dispatch(KeyCombo("F3")!, .pressed, in: mix)
        engine.stop()
        engine.dispatch(KeyCombo("F3")!, .released, in: mix)
        #expect(events.list == ["press", "release"])
    }

    @Test func nestedRunWaitsAndSeesItsTrigger() async throws {
        let events = Events()
        let engine = engine([
            Macro("test.outer", "Outer", group: .floTools, triggers: [.key("F1")]) { @MainActor run in
                events.list.append("outer")
                try await run.run("test.inner")
                events.list.append("outer end")
            },
            // Disabled and in another group's window: nested runs ignore both, as KM's Execute Macro did.
            Macro("test.inner", "Inner", group: .plugin, enabledByDefault: false, triggers: []) { @MainActor run in
                events.list.append("inner by \(run.trigger)")
            },
        ])
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        await engine.waitUntilIdle()
        #expect(events.list == ["outer", "inner by nested(by: test.outer)", "outer end"])
    }

    @Test func nestedCycleIsAnError() async throws {
        let events = Events()
        let engine = engine([
            Macro("test.a", "A", group: .floTools, triggers: [.key("F1")]) { @MainActor run in
                do {
                    try await run.run("test.b")
                } catch {
                    events.list.append("\(error)")
                }
            },
            Macro("test.b", "B", group: .floTools, triggers: []) { @MainActor run in try await run.run("test.a") },
        ])
        engine.dispatch(KeyCombo("F1")!, .pressed, in: mix)
        await engine.waitUntilIdle()
        #expect(events.list == ["macro cycle: test.a -> test.b -> test.a"])
    }

    @Test func stopCancelsARunningMacro() async throws {
        let events = Events()
        var signalStarted: AsyncStream<Void>.Continuation?
        let started = AsyncStream<Void> { signalStarted = $0 }
        let engine = engine([
            Macro("test.long", "Long", group: .floTools, triggers: [.key("F1")]) { @MainActor [signalStarted] _ in
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
        // Stop only once the body runs, so the test checks cancellation of a running macro, not of a queued one.
        for await _ in started { break }
        engine.stop()
        await engine.waitUntilIdle()
        #expect(events.list == ["cancelled"])
    }

    @Test func batchedChangesAreAllApplied() {
        let engine = FloMacros.makeEngine()
        InspectorMode.setInspector(false, in: engine)
        #expect(!engine.isGroupActivated(.inspector))
        #expect(engine.isMacroEnabled(InspectorMode.nextTrackView))
        #expect(engine.isMacroEnabled(InspectorMode.previousTrackView))
    }

    @Test func doneSoundTimingMatchesJXA() throws {
        func doneSound(_ id: MacroID) throws -> DoneSoundTiming? {
            let macro = try #require(FloMacros.all.first { $0.id == id })
            guard case .singleOrDouble(_, _, let doneSound) = macro.action else { return nil }
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
}

@MainActor @Suite struct VoiceOverTests {
    @Test func failureReasons() {
        #expect(VoiceOver.failureReason(status: -600) == "VoiceOver is not running")
        #expect(VoiceOver.failureReason(status: -1712) == "VoiceOver did not answer within 2 seconds")
        #expect(VoiceOver.failureReason(status: -1743) == "Flo Tools may not control VoiceOver (Automation permission)")
        #expect(VoiceOver.failureReason(status: -1708) == "Apple event error -1708")
    }
}

@Suite struct PreferencesTests {
    @Test func readsKeyboardMaestroFormat() {
        let json = #"{"temporary inspector":true,"starts with Flo Tools inspector":true,"timeout":"300"}"#
        let prefs = Preferences.decode(Data(json.utf8))
        #expect(prefs.temporaryInspector)
        #expect(prefs.startsWithInspector)
        #expect(prefs.timeout == 300)
    }

    @Test func roundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        var prefs = Preferences()
        prefs.timeout = 400
        prefs.temporaryInspector = true
        try prefs.save(to: url)
        #expect(Preferences.load(from: url) == prefs)
    }
}

@Suite struct MacroTextTests {
    @Test func keyComboParsesItsDescription() {
        for code in KeyCombo.keyNames.keys {
            for modifiers: UInt32 in [0, KeyCombo.command, KeyCombo.control | KeyCombo.option | KeyCombo.shift] {
                let combo = KeyCombo(keyCode: code, modifiers: modifiers)
                #expect(KeyCombo(combo.description) == combo, "\(combo)")
            }
        }
        #expect(KeyCombo("Ctrl+Nope") == nil)
    }

    @Test func keyComboNames() {
        #expect(KeyCombo(keyCode: 1, modifiers: KeyCombo.option | KeyCombo.shift).description == "Opt+Shift+S")
        #expect(KeyCombo(keyCode: 78, modifiers: KeyCombo.control | KeyCombo.option).description == "Ctrl+Opt+Keypad -")
    }

    @Test func sendMessageMatchesJXA() {
        #expect(Inspector.sendMessage(selectorName: "Send selector B", selectorValue: "unassigned", assignmentValue: "unassigned") == " B. : unassigned")
        #expect(Inspector.sendMessage(selectorName: "Send selector B", selectorValue: "Bus 1", assignmentValue: "Send Assignment Reverb") == " B. Bus 1: Reverb")
    }

    @Test func soloStateTextMatchesJXA() {
        #expect(Inspector.soloStateText("Selected") == "On")
        #expect(Inspector.soloStateText("") == "Off")
        #expect(Inspector.soloStateText("off safe") == "off safe")
    }

    @Test func soloFilter() {
        #expect(TrackStatus.isSoloed(trackName: "Kick - Audio Track ", soloValue: "on"))
        #expect(!TrackStatus.isSoloed(trackName: "Kick - Audio Track ", soloValue: ""))
        #expect(!TrackStatus.isSoloed(trackName: "Kick - Audio Track ", soloValue: "on, solo safe"))
        #expect(!TrackStatus.isSoloed(trackName: "Kick - Audio Track ", soloValue: "Inactive"))
        #expect(!TrackStatus.isSoloed(trackName: "Master 1 - Master Track ", soloValue: "on"))
    }

    @Test func soloedMessageMatchesJXA() {
        #expect(TrackStatus.soloedMessage(names: []) == "No tracks are soloed.")
        #expect(TrackStatus.soloedMessage(names: ["Kick - Audio Track ", "Snare - Audio Track "]) == "2 Soloed: Kick - Audio. Snare - Audio. ")
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
