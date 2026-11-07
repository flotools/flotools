import Foundation
import Testing
@testable import FloEngine
@testable import FloFeatures
@testable import FloProTools
import FloSystem

@Suite @MainActor struct AutoInspectorTests {
    let mix = FrontContext(bundleID: ProToolsApp.bundleID, windowTitle: "Mix: Session", windowNumber: 1, processID: 100)
    let key = KeyCombo(literal: "Ctrl+Cmd+Right")
    let a = InspectorTarget(processID: 100, name: "A - Audio Track ")
    let b = InspectorTarget(processID: 100, name: "B - Audio Track ")

    @MainActor final class Probe {
        var events: [String] = []
        var calls = 0
        var reply: CheckedContinuation<InspectorTarget?, any Error>?
        var requested: CheckedContinuation<Void, Never>?

        func detect() async throws -> InspectorTarget? {
            calls += 1
            return try await withCheckedThrowingContinuation { continuation in
                reply = continuation
                requested?.resume()
                requested = nil
            }
        }

        func waitForRequest() async {
            if reply != nil { return }
            await withCheckedContinuation { requested = $0 }
        }

        func resolve(_ target: InspectorTarget?) {
            let continuation = reply
            reply = nil
            continuation?.resume(returning: target)
        }
    }

    func engine(_ probe: Probe, double: Bool = false, repeating: Bool = false, key: String = "Ctrl+Cmd+Right") -> Engine {
        let body: CommandBody = { @MainActor run in probe.events.append("single " + (run.inspectorTarget?.name ?? "manual")) }
        let command: Command
        if double {
            command = Command("test.inspector", "Inspector", scope: .mixOrEdit, mode: .inspectorOn, triggers: [.key(key)], doneSound: .none, single: body, double: { @MainActor run in probe.events.append("double " + (run.inspectorTarget?.name ?? "manual")) })
        } else if repeating {
            command = Command.repeatingWhileHeld("test.inspector", "Inspector", scope: .mixOrEdit, mode: .inspectorOn, triggers: [.key(key)], body: body)
        } else {
            command = Command("test.inspector", "Inspector", scope: .mixOrEdit, mode: .inspectorOn, triggers: [.key(key)], body: body)
        }
        let conflict = Command("test.trackView", "Track view", scope: .mixOrEdit, mode: .inspectorOff, triggers: [.key(key)]) { @MainActor _ in probe.events.append("track view") }
        let engine = FloFeatures.makeEngine(commands: [command, conflict])
        engine.autoInspector = true
        engine.detectInspectorTarget = { _ in try await probe.detect() }
        engine.forwardInspectorKey = { _, _ in probe.events.append("forward") }
        return engine
    }

    @Test func defaultPersistenceAndApplication() {
        let suite = TestDefaults("auto-inspector")
        #expect(!PreferencesStore(defaults: suite.defaults).current.autoInspector)
        var preferences = Preferences()
        preferences.autoInspector = true
        PreferencesStore(defaults: suite.defaults).save(preferences)
        #expect(PreferencesStore(defaults: suite.defaults).current.autoInspector)
        let engine = FloFeatures.makeEngine()
        FloFeatures.apply(preferences, to: engine)
        #expect(engine.autoInspector)
        preferences.autoInspector = false
        FloFeatures.apply(preferences, to: engine)
        #expect(!engine.autoInspector)
    }

    @Test func inspectorOnlyKeysRegisterWhileRuntimeModeIsOff() {
        let engine = FloFeatures.makeEngine()
        let solo = KeyCombo(literal: "S")
        #expect(!engine.activeCombos(in: mix).contains(solo))
        engine.autoInspector = true
        #expect(engine.activeCombos(in: mix).contains(solo))
        #expect(engine.activeCombos(in: FrontContext(bundleID: ProToolsApp.bundleID, windowTitle: "Edit: Session")).contains(solo))
        #expect(!engine.activeCombos(in: FrontContext(bundleID: ProToolsApp.bundleID)).contains(solo))
        engine.setCommand("inspector.speakToggleSolo", enabled: false)
        #expect(!engine.activeCombos(in: mix).contains(solo))
    }

    @Test(arguments: ["Ctrl+Cmd+Left", "Ctrl+Cmd+Right"])
    func nonmatchBypassesBothTrackViewBindings(_ literal: String) async {
        let probe = Probe()
        let engine = engine(probe, key: literal)
        engine.dispatch(KeyCombo(literal: literal), .pressed, in: mix)
        await probe.waitForRequest()
        probe.resolve(nil)
        await engine.waitUntilIdle()
        #expect(probe.events == ["forward"])
    }

    @Test func registrationAndManualBehavior() async {
        let probe = Probe()
        let engine = engine(probe)
        #expect(engine.activeCombos(in: mix).contains(key))
        #expect(!engine.activeCombos(in: FrontContext(bundleID: ProToolsApp.bundleID, windowTitle: "Plug-in: X")).contains(key))
        engine.autoInspector = false
        engine.dispatch(key, .pressed, in: mix)
        await engine.waitUntilIdle()
        #expect(probe.calls == 0)
        #expect(probe.events == ["track view"])
    }

    @Test(arguments: [false, true]) func nonmatchAndFailureForwardDirectly(_ failure: Bool) async {
        let probe = Probe()
        let engine = engine(probe)
        engine.setInspector(true)
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        if failure {
            probe.reply?.resume(throwing: FloError.voiceOver("test failure"))
            probe.reply = nil
        } else { probe.resolve(nil) }
        await engine.waitUntilIdle()
        #expect(probe.events == ["forward"])
        #expect(!engine.mode.inspector)
        #expect(engine.autoInspector)
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        probe.resolve(a)
        await engine.waitUntilIdle()
        #expect(probe.events == ["forward", "single " + a.name])
        #expect(engine.mode.inspector)
    }

    @Test(arguments: ["context", "preference", "disable", "suspend", "cancel", "timeout"])
    func staleDetectionDoesNothing(_ change: String) async {
        let probe = Probe()
        let engine = engine(probe)
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        switch change {
        case "context": engine.contextChanged(to: FrontContext(bundleID: ProToolsApp.bundleID, windowTitle: "Mix: Session", windowNumber: 2, processID: 100))
        case "preference": engine.autoInspector = false
        case "disable": engine.isEnabled = false
        case "suspend": engine.suspend(Suspension("test"))
        case "timeout": engine.doublePressTimeout = .milliseconds(100)
        default: engine.cancelAll()
        }
        probe.resolve(a)
        await engine.waitUntilIdle()
        #expect(probe.events.isEmpty)
        #expect(!engine.mode.inspector)
    }

    @Test func orderedProbesAndCapturedTargets() async {
        let probe = Probe()
        let engine = engine(probe)
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        engine.dispatch(key, .pressed, in: mix)
        #expect(probe.calls == 1)
        probe.resolve(a)
        await probe.waitForRequest()
        probe.resolve(b)
        await engine.waitUntilIdle()
        #expect(probe.events == ["single " + a.name, "single " + b.name])
    }

    @Test(arguments: [true, false]) func doublesRequireSameTarget(_ same: Bool) async {
        let probe = Probe()
        let engine = engine(probe, double: true)
        let arrival = ContinuousClock.now
        engine.dispatch(key, .pressed, in: mix, at: arrival)
        await probe.waitForRequest()
        engine.dispatch(key, .pressed, in: mix, at: arrival + .milliseconds(10))
        probe.resolve(a)
        await probe.waitForRequest()
        probe.resolve(same ? a : b)
        await engine.waitUntilIdle()
        #expect(probe.events == (same ? ["double " + a.name] : ["single " + a.name, "single " + b.name]))
    }

    @Test func physicalArrivalOutsideTimeoutIsTwoSingles() async {
        let probe = Probe()
        let engine = engine(probe, double: true)
        let arrival = ContinuousClock.now - .seconds(2)
        engine.dispatch(key, .pressed, in: mix, at: arrival)
        await probe.waitForRequest()
        engine.dispatch(key, .pressed, in: mix, at: arrival + .seconds(1))
        probe.resolve(a)
        await probe.waitForRequest()
        probe.resolve(a)
        await engine.waitUntilIdle()
        #expect(probe.events == ["single " + a.name, "single " + a.name])
    }

    @Test(arguments: [true, false])
    func unrelatedDoublePressKeepsPhysicalTimingAcrossProbe(_ withinTimeout: Bool) async throws {
        let probe = Probe()
        let regularKey = KeyCombo(literal: "Opt+Shift+S")
        let regular = Command("test.regular", "Regular", scope: .mixOrEdit, triggers: [.key("Opt+Shift+S")], doneSound: .none, single: { @MainActor _ in
            probe.events.append("regular single")
        }, double: { @MainActor _ in
            probe.events.append("regular double")
        })
        let inspector = Command("test.inspector", "Inspector", scope: .mixOrEdit, mode: .inspectorOn, triggers: [.key("S")]) { _ in }
        let engine = FloFeatures.makeEngine(commands: [regular, inspector])
        engine.autoInspector = true
        engine.detectInspectorTarget = { _ in try await probe.detect() }
        engine.forwardInspectorKey = { _, _ in probe.events.append("forward") }
        let first = ContinuousClock.now - .seconds(2)
        engine.dispatch(regularKey, .pressed, in: mix, at: first)
        engine.dispatch(KeyCombo(literal: "S"), .pressed, in: mix, at: first + .milliseconds(20))
        await probe.waitForRequest()
        // The first deadline is already past; allow its timer to run while detection remains blocked.
        try await Task.sleep(for: .milliseconds(20))
        engine.dispatch(regularKey, .pressed, in: mix, at: first + .milliseconds(withinTimeout ? 100 : 500))
        probe.resolve(nil)
        await engine.waitUntilIdle()
        let regularEvents = probe.events.filter { $0.hasPrefix("regular") }
        #expect(regularEvents == (withinTimeout ? ["regular double"] : ["regular single", "regular single"]))
        #expect(probe.events.filter { $0 == "forward" }.count == 1)
    }

    @Test func forwardedPressBreaksPendingDouble() async {
        let probe = Probe()
        let engine = engine(probe, double: true)
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        engine.dispatch(key, .pressed, in: mix)
        probe.resolve(a)
        await probe.waitForRequest()
        probe.resolve(nil)
        await engine.waitUntilIdle()
        #expect(probe.events == ["forward"])
    }

    @Test(arguments: [true, false]) func releaseDuringProbeAllowsTapOnly(_ repeating: Bool) async {
        let probe = Probe()
        let engine = engine(probe, double: !repeating, repeating: repeating)
        engine.doublePressHold = .zero
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        engine.dispatch(key, .released, in: mix)
        probe.resolve(a)
        await engine.waitUntilIdle()
        #expect(probe.events == ["single " + a.name])
    }

    @Test func pendingProbeDoesNotDelayAnExistingHoldRelease() async {
        let probe = Probe()
        let engine = FloFeatures.makeEngine(commands: [Command("test.hold", "Hold", scope: .mixOrEdit, mode: .inspectorOn, triggers: [.key("S"), .key("M")], press: { _ in
            probe.events.append("press")
            return true
        }, release: { _ in probe.events.append("release") })])
        engine.autoInspector = true
        engine.detectInspectorTarget = { _ in try await probe.detect() }
        engine.forwardInspectorKey = { _, _ in probe.events.append("forward") }
        engine.dispatch(KeyCombo(literal: "S"), .pressed, in: mix)
        await probe.waitForRequest()
        probe.resolve(a)
        await engine.waitUntilIdle()
        engine.dispatch(KeyCombo(literal: "M"), .pressed, in: mix)
        await probe.waitForRequest()
        engine.dispatch(KeyCombo(literal: "S"), .released, in: mix)
        #expect(probe.events == ["press", "release"])
        probe.resolve(nil)
        await engine.waitUntilIdle()
        #expect(probe.events == ["press", "release", "forward"])
    }

    @Test(arguments: [false, true]) func inspectorOffEndsHoldDespiteContinuedRegistration(_ manual: Bool) async {
        let probe = Probe()
        let engine = FloFeatures.makeEngine(commands: [Command("test.hold", "Hold", scope: .mixOrEdit, mode: .inspectorOn, triggers: [.key("S"), .key("M")], press: { _ in
            probe.events.append("press")
            return true
        }, release: { _ in probe.events.append("release") })])
        engine.autoInspector = true
        engine.detectInspectorTarget = { _ in try await probe.detect() }
        engine.forwardInspectorKey = { _, _ in probe.events.append("forward") }
        engine.dispatch(KeyCombo(literal: "S"), .pressed, in: mix)
        await probe.waitForRequest()
        probe.resolve(a)
        await engine.waitUntilIdle()
        if manual {
            engine.setInspector(false)
        } else {
            engine.dispatch(KeyCombo(literal: "M"), .pressed, in: mix)
            await probe.waitForRequest()
            probe.resolve(nil)
            await engine.waitUntilIdle()
        }
        #expect(engine.activeCombos(in: mix).contains(KeyCombo(literal: "S")))
        #expect(probe.events == (manual ? ["press", "release"] : ["press", "release", "forward"]))
    }

    @Test func suspendedEngineDoesNotProbe() async {
        let probe = Probe()
        let engine = engine(probe)
        engine.suspend(Suspension("test"))
        #expect(engine.dispatch(key, .pressed, in: mix) == nil)
        await engine.waitUntilIdle()
        #expect(probe.calls == 0)
        #expect(probe.events.isEmpty)
    }

    @Test func manualModeChangeDoesNotBypassNextProbe() async {
        let probe = Probe()
        let engine = engine(probe)
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        engine.setInspector(false)
        probe.resolve(a)
        await engine.waitUntilIdle()
        #expect(probe.events == ["single " + a.name])
        #expect(engine.mode.inspector)
        engine.autoInspector = false
        #expect(engine.mode.inspector)
    }

    @Test func exactNameGeometryRejectsNeighborAndInvalidFrames() {
        let frame = CGRect(x: 10, y: 20, width: 100, height: 300)
        #expect(ProToolsApp.isInspectorName(text: a.name, bounds: frame, name: a.name, frame: frame))
        #expect(!ProToolsApp.isInspectorName(text: a.name, bounds: CGRect(x: 10, y: 20, width: 20, height: 20), name: a.name, frame: frame))
        #expect(!ProToolsApp.isInspectorName(text: "Solo", bounds: frame, name: a.name, frame: frame))
        #expect(!ProToolsApp.isInspectorName(text: a.name, bounds: .zero, name: a.name, frame: .zero))
        #expect(!ProToolsApp.isInspectorName(text: a.name, bounds: .infinite, name: a.name, frame: .infinite))
    }
}
