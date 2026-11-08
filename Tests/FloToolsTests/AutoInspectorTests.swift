import ApplicationServices
import Foundation
import Testing
@testable import FloEngine
@testable import FloFeatures
@testable import FloProTools
@testable import FloSystem

@Suite @MainActor struct AutoInspectorTests {
    let mix = FrontContext(bundleID: ProToolsApp.bundleID, windowTitle: "Mix: Session", windowNumber: 1, processID: 100)
    let key = KeyCombo(literal: "Ctrl+Cmd+Right")
    let a: InspectorTarget
    let b: InspectorTarget

    init() async { (a, b) = await Self.targets() }

    /// One element for both: these tests tell tracks apart by name only.
    @AccessibilityActor
    static func targets() -> (InspectorTarget, InspectorTarget) {
        let element = AXElement.application(pid: 100)
        return (InspectorTarget(processID: 100, name: "A - Audio Track ", source: element, window: .mix),
                InspectorTarget(processID: 100, name: "B - Audio Track ", source: element, window: .mix))
    }

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

    nonisolated static let invalidatingChanges = ["context", "preference", "disable", "suspend", "cancel", "timeout"]

    /// Makes one of the changes that void a press still being decided.
    static func invalidate(_ engine: Engine, by change: String) {
        switch change {
        case "context": engine.contextChanged(to: FrontContext(bundleID: ProToolsApp.bundleID, windowTitle: "Mix: Session", windowNumber: 2, processID: 100))
        case "preference": engine.autoInspector = false
        case "disable": engine.isEnabled = false
        case "suspend": engine.suspend(Suspension("test"))
        case "timeout": engine.doubleActionTrigger = .secondPress(within: .milliseconds(100))
        default: engine.cancelAll()
        }
    }

    @Test(arguments: invalidatingChanges)
    func staleDetectionDoesNothing(_ change: String) async {
        let probe = Probe()
        let engine = engine(probe)
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        Self.invalidate(engine, by: change)
        probe.resolve(a)
        await engine.waitUntilIdle()
        #expect(probe.events.isEmpty)
        #expect(!engine.mode.inspector)
    }

    /// A change while the key capture check waits voids the press, like one during detection.
    @Test(arguments: invalidatingChanges)
    func staleKeyCaptureCheckDoesNothing(_ change: String) async {
        let probe = Probe()
        let engine = engine(probe)
        engine.keyCapture = { [weak engine] _ in
            if let engine { Self.invalidate(engine, by: change) }
            return nil
        }
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        probe.resolve(a)
        await engine.waitUntilIdle()
        #expect(probe.events.isEmpty)
        #expect(!engine.mode.inspector)
    }

    /// Tracks are told apart by AX identity, so two strips with one name are two tracks and their presses two singles.
    @Test func sameNameOnDifferentElementsIsNoDouble() async {
        let (first, second) = await Self.sameNameTargets()
        let probe = Probe()
        let engine = engine(probe, double: true)
        let arrival = ContinuousClock.now
        engine.dispatch(key, .pressed, in: mix, at: arrival)
        await probe.waitForRequest()
        engine.dispatch(key, .pressed, in: mix, at: arrival + .milliseconds(10))
        probe.resolve(first)
        await probe.waitForRequest()
        probe.resolve(second)
        await engine.waitUntilIdle()
        #expect(probe.events == ["single " + a.name, "single " + a.name])
    }

    @AccessibilityActor
    static func sameNameTargets() -> (InspectorTarget, InspectorTarget) {
        (InspectorTarget(processID: 100, name: "A - Audio Track ", source: AXElement.application(pid: 100), window: .mix),
         InspectorTarget(processID: 100, name: "A - Audio Track ", source: AXElement.application(pid: 101), window: .mix))
    }

    @AccessibilityActor
    static func target(inProcess pid: pid_t) -> InspectorTarget {
        InspectorTarget(processID: pid, name: "A - Audio Track ", source: AXElement.application(pid: pid), window: .mix)
    }

    /// A track of another app than the one the key was pressed in is not a target there.
    @Test func targetInAnotherProcessForwards() async {
        let other = await Self.target(inProcess: 200)
        let probe = Probe()
        let engine = engine(probe)
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        probe.resolve(other)
        await engine.waitUntilIdle()
        #expect(probe.events == ["forward"])
        #expect(!engine.mode.inspector)
    }

    /// An accepted run waiting behind a slow one is dropped when what it was accepted under changes before it starts. Changing the double-press timeout leaves every other queue check passing, so only the input generation can drop it.
    @Test func queuedAcceptedRunIsDroppedWhenInputIsVoided() async {
        let probe = Probe()
        var gate: CheckedContinuation<Void, Never>?
        var started: CheckedContinuation<Void, Never>?
        let command = Command("test.inspector", "Inspector", scope: .mixOrEdit, mode: .inspectorOn, triggers: [.key("Ctrl+Cmd+Right")]) { @MainActor run in
            probe.events.append("start " + (run.inspectorTarget?.name ?? "manual"))
            if probe.events.count == 1 {
                await withCheckedContinuation { gate = $0; started?.resume() }
            }
        }
        let engine = FloFeatures.makeEngine(commands: [command])
        engine.autoInspector = true
        engine.detectInspectorTarget = { _ in try await probe.detect() }
        engine.forwardInspectorKey = { _, _ in probe.events.append("forward") }
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        await withCheckedContinuation { continuation in
            started = continuation
            probe.resolve(a)
        }
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        probe.resolve(b)
        await engine.waitForAdmissions()
        engine.doubleActionTrigger = .secondPress(within: .milliseconds(100))
        gate?.resume()
        await engine.waitUntilIdle()
        #expect(probe.events == ["start " + a.name])
    }

    /// Every line a press causes carries the ID `dispatch` returned, including a single run after its timeout.
    @Test(arguments: [false, true]) func runsKeepTheirInvocationID(_ double: Bool) async {
        let probe = Probe()
        var seen: [String?] = []
        let body: CommandBody = { @MainActor _ in seen.append(Log.invocation) }
        let command = double
            ? Command("test.inspector", "Inspector", scope: .mixOrEdit, mode: .inspectorOn, triggers: [.key("Ctrl+Cmd+Right")], doneSound: .none, single: body, double: body)
            : Command("test.inspector", "Inspector", scope: .mixOrEdit, mode: .inspectorOn, triggers: [.key("Ctrl+Cmd+Right")], body: body)
        let engine = FloFeatures.makeEngine(commands: [command])
        engine.autoInspector = true
        engine.doubleActionTrigger = .secondPress(within: .milliseconds(20))
        engine.detectInspectorTarget = { _ in try await probe.detect() }
        let id = engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        probe.resolve(a)
        await engine.waitUntilIdle()
        #expect(id != nil)
        #expect(seen == [id])
    }

    /// A repeat's delay starts when its first run starts, after detection, not when the key went down; otherwise a slow check would make it repeat at once.
    @Test func repeatDelayStartsAfterASlowProbe() async throws {
        let probe = Probe()
        var times: [ContinuousClock.Instant] = []
        let command = Command.repeatingWhileHeld("test.inspector", "Inspector", scope: .mixOrEdit, mode: .inspectorOn, triggers: [.key("Ctrl+Cmd+Right")]) { @MainActor _ in
            times.append(.now)
        }
        let engine = FloFeatures.makeEngine(commands: [command])
        engine.autoInspector = true
        engine.keyRepeat = { KeyRepeat(delay: .milliseconds(150), interval: .seconds(10)) { _ in true } }
        engine.detectInspectorTarget = { _ in try await probe.detect() }
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        try await Task.sleep(for: .milliseconds(300))
        probe.resolve(a)
        while times.count < 2 { try await Task.sleep(for: .milliseconds(10)) }
        engine.dispatch(key, .released, in: mix)
        await engine.waitUntilIdle()
        #expect(times[1] - times[0] >= .milliseconds(120))
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
        engine.doubleActionTrigger = .hold(for: .zero)
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

    /// The VoiceOver cursor still reports the track behind a menu opened from it or a counter opened for typing, so a capture must forward even when detection finds a track.
    @Test(arguments: [KeyCapture.menu, .textField])
    func keyCaptureForwardsDespiteTrackTarget(_ capture: KeyCapture) async {
        let probe = Probe()
        let engine = engine(probe)
        engine.keyCapture = { _ in capture }
        engine.setInspector(true)
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        probe.resolve(a)
        await engine.waitUntilIdle()
        #expect(probe.events == ["forward"])
        #expect(!engine.mode.inspector)
        engine.keyCapture = { _ in nil }
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        probe.resolve(a)
        await engine.waitUntilIdle()
        #expect(probe.events == ["forward", "single " + a.name])
        #expect(engine.mode.inspector)
    }

    /// When the check for a menu or field fails, as while Pro Tools is busy, nobody knows whether a field is open, so the key goes to Pro Tools.
    @Test func failedKeyCaptureCheckForwards() async {
        let probe = Probe()
        let engine = engine(probe)
        engine.keyCapture = { _ in throw FloError.accessibility(operation: "AXFocusedUIElement", code: AXError.cannotComplete.rawValue) }
        engine.setInspector(true)
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        probe.resolve(a)
        await engine.waitUntilIdle()
        #expect(probe.events == ["forward"])
        #expect(!engine.mode.inspector)
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

    /// A removed strip's element can no longer be read, so the command fails rather than looking the name up again, which could find a strip recreated with that name.
    @Test func removedAcceptedTrackThrows() async {
        await #expect(throws: FloError.self) { try await Self.removedTarget().track(in: .mix) }
    }

    @AccessibilityActor
    static func removedTarget() -> InspectorTarget {
        // No process has this ID, so reads of the element fail as they do for a removed strip.
        InspectorTarget(processID: 99_999, name: "A - Audio Track ", source: AXElement.application(pid: 99_999), window: .mix)
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
