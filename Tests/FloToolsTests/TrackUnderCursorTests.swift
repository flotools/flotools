import ApplicationServices
import Foundation
import Testing
@testable import FloEngine
@testable import FloFeatures
@testable import FloProTools
@testable import FloSystem

/// Commands scoped to the track under the VoiceOver cursor: the engine checks the cursor at each press, in order, and runs the next command for the key, or passes the key on, when the cursor is not on a track.
@Suite @MainActor struct TrackUnderCursorTests {
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

    @AccessibilityActor
    static func target(inProcess pid: pid_t) -> InspectorTarget {
        InspectorTarget(processID: pid, name: "A - Audio Track ", source: AXElement.application(pid: pid), window: .mix)
    }

    /// Answers each cursor check when the test says so, and records what the commands did.
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

    enum Kind { case plain, tapOrHold, repeating }

    /// A track command of `kind` on `key`, and a Mix or Edit command on the same key for off a track, as Ctrl+Cmd+Right pans on a track and changes the track view off it.
    func engine(_ probe: Probe, _ kind: Kind = .plain, key: String = "Ctrl+Cmd+Right", offTrack: Bool = true) -> Engine {
        let record: (String) -> CommandBody = { label in { @MainActor run in probe.events.append(label + " " + (run.inspectorTarget?.name ?? "none")) } }
        let command = switch kind {
        case .plain: Command("test.track", "Track", scope: .trackUnderVoiceOverCursor, triggers: [.key(key)], body: record("run"))
        case .tapOrHold: Command("test.track", "Track", scope: .trackUnderVoiceOverCursor, triggers: [.key(key)], doneSound: .none, tap: record("tap"), hold: record("hold"))
        case .repeating: Command.repeatingWhileHeld("test.track", "Track", scope: .trackUnderVoiceOverCursor, triggers: [.key(key)], body: record("run"))
        }
        let trackView = Command("test.trackView", "Track view", scope: .mixOrEdit, triggers: [.key(key)]) { @MainActor _ in probe.events.append("track view") }
        return trackEngine(probe, offTrack ? [command, trackView] : [command])
    }

    /// An engine that asks `probe` for each cursor check, records a passed-on key as "forward", and finds every key up.
    func trackEngine(_ probe: Probe, _ commands: [Command]) -> Engine {
        let engine = FloFeatures.makeEngine(commands: commands)
        engine.detectInspectorTarget = { _ in try await probe.detect() }
        engine.postKey = { _, _ in probe.events.append("forward") }
        engine.keyCapture = { _ in nil }
        engine.keyRepeat = { KeyRepeat(delay: .milliseconds(5), interval: .milliseconds(5)) { _ in false } }
        return engine
    }

    @Test func pressOnATrackRunsTheTrackCommand() async {
        let probe = Probe()
        let engine = engine(probe)
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        probe.resolve(a)
        await engine.waitUntilIdle()
        #expect(probe.events == ["run " + a.name])
    }

    /// Off a track, or when the cursor cannot be read, the key does what it does without the cursor check.
    @Test(arguments: [false, true]) func offATrackTheNextCommandRuns(_ failure: Bool) async {
        let probe = Probe()
        let engine = engine(probe)
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        if failure {
            probe.reply?.resume(throwing: FloError.voiceOver("test failure"))
            probe.reply = nil
        } else { probe.resolve(nil) }
        await engine.waitUntilIdle()
        #expect(probe.events == ["track view"])
    }

    @Test(arguments: ["Ctrl+Cmd+Left", "S"])
    func offATrackWithNoOtherCommandTheKeyIsPassedOn(_ literal: String) async {
        let probe = Probe()
        let engine = engine(probe, key: literal, offTrack: false)
        engine.dispatch(KeyCombo(literal: literal), .pressed, in: mix)
        await probe.waitForRequest()
        probe.resolve(nil)
        await engine.waitUntilIdle()
        #expect(probe.events == ["forward"])
    }

    /// A track of another app than the one the key was pressed in does not count as on a track.
    @Test func targetInAnotherProcessIsOffATrack() async {
        let other = await Self.target(inProcess: 200)
        let probe = Probe()
        let engine = engine(probe)
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        probe.resolve(other)
        await engine.waitUntilIdle()
        #expect(probe.events == ["track view"])
    }

    nonisolated static let invalidatingChanges = ["context", "hold time", "disable", "suspend", "cancel"]

    /// Makes one of the changes that void a press still being decided.
    static func invalidate(_ engine: Engine, by change: String) {
        switch change {
        case "context": engine.contextChanged(to: FrontContext(bundleID: ProToolsApp.bundleID, windowTitle: "Mix: Session", windowNumber: 2, processID: 100))
        case "hold time": engine.holdTime = .milliseconds(100)
        case "disable": engine.isEnabled = false
        case "suspend": engine.suspend(Suspension("test"))
        default: engine.cancelAll()
        }
    }

    @Test(arguments: invalidatingChanges)
    func staleCursorCheckDoesNothing(_ change: String) async {
        let probe = Probe()
        let engine = engine(probe)
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        Self.invalidate(engine, by: change)
        probe.resolve(a)
        await engine.waitUntilIdle()
        #expect(probe.events.isEmpty)
    }

    /// A change while the key capture check waits voids the press, like one during the cursor check.
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
    }

    /// The VoiceOver cursor still reports the track behind a menu opened from it or a counter opened for typing, so a capture passes the key on even when the cursor is on a track.
    @Test(arguments: [KeyCapture.menu, .textField])
    func keyCapturePassesTheKeyOnDespiteATrack(_ capture: KeyCapture) async {
        let probe = Probe()
        let engine = engine(probe)
        engine.keyCapture = { _ in capture }
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        probe.resolve(a)
        await engine.waitUntilIdle()
        #expect(probe.events == ["forward"])
    }

    /// When the check for a menu or field fails, as while Pro Tools is busy, nobody knows whether a field is open, so the key goes to Pro Tools.
    @Test func failedKeyCaptureCheckPassesTheKeyOn() async {
        let probe = Probe()
        let engine = engine(probe)
        engine.keyCapture = { _ in throw FloError.accessibility(operation: "AXFocusedUIElement", code: AXError.cannotComplete.rawValue) }
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        probe.resolve(a)
        await engine.waitUntilIdle()
        #expect(probe.events == ["forward"])
    }

    @Test func suspendedEngineDoesNotCheckTheCursor() async {
        let probe = Probe()
        let engine = engine(probe)
        engine.suspend(Suspension("test"))
        #expect(engine.dispatch(key, .pressed, in: mix) == nil)
        await engine.waitUntilIdle()
        #expect(probe.calls == 0)
        #expect(probe.events.isEmpty)
    }

    /// Each press keeps the track found for it, and the second check starts only after the first ends.
    @Test func checksRunInOrderAndKeepTheirTracks() async {
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
        #expect(probe.events == ["run " + a.name, "run " + b.name])
    }

    /// A later key that needs no cursor check still waits for an earlier press's check, so presses run in the order they came.
    @Test func laterKeyWaitsForAnEarlierCheck() async {
        let probe = Probe()
        let other = Command("test.other", "Other", scope: .anyProToolsWindow, triggers: [.key("F2")]) { @MainActor _ in probe.events.append("other") }
        let engine = trackEngine(probe, [Command("test.track", "Track", scope: .trackUnderVoiceOverCursor, triggers: [.key("S")]) { @MainActor _ in probe.events.append("track") }, other])
        engine.dispatch(KeyCombo(literal: "S"), .pressed, in: mix)
        await probe.waitForRequest()
        engine.dispatch(KeyCombo(literal: "F2"), .pressed, in: mix)
        await Task.yield()
        #expect(probe.events.isEmpty)
        probe.resolve(a)
        await engine.waitUntilIdle()
        #expect(probe.events == ["track", "other"])
    }

    /// A run waiting behind a slow one is dropped when what it was accepted under changes before it starts. Changing the hold time leaves every other queue check passing, so only the input generation can drop it.
    @Test func queuedAcceptedRunIsDroppedWhenInputIsVoided() async {
        let probe = Probe()
        var gate: CheckedContinuation<Void, Never>?
        var started: CheckedContinuation<Void, Never>?
        let command = Command("test.track", "Track", scope: .trackUnderVoiceOverCursor, triggers: [.key("Ctrl+Cmd+Right")]) { @MainActor run in
            probe.events.append("start " + (run.inspectorTarget?.name ?? "none"))
            if probe.events.count == 1 {
                await withCheckedContinuation { gate = $0; started?.resume() }
            }
        }
        let engine = trackEngine(probe, [command])
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
        engine.holdTime = .milliseconds(100)
        gate?.resume()
        await engine.waitUntilIdle()
        #expect(probe.events == ["start " + a.name])
    }

    /// Every line a press causes carries the ID `dispatch` returned, including a tap decided after the key went up.
    @Test(arguments: [Kind.plain, .tapOrHold]) func runsKeepTheirInvocationID(_ kind: Kind) async {
        let probe = Probe()
        var seen: [String?] = []
        let body: CommandBody = { @MainActor _ in seen.append(Log.invocation) }
        let command = kind == .tapOrHold
            ? Command("test.track", "Track", scope: .trackUnderVoiceOverCursor, triggers: [.key("Ctrl+Cmd+Right")], doneSound: .none, tap: body, hold: body)
            : Command("test.track", "Track", scope: .trackUnderVoiceOverCursor, triggers: [.key("Ctrl+Cmd+Right")], body: body)
        let engine = trackEngine(probe, [command])
        let id = engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        probe.resolve(a)
        await engine.waitUntilIdle()
        #expect(id != nil)
        #expect(seen == [id])
    }

    /// A repeat's delay starts when its first run starts, after the cursor check, not when the key went down; otherwise a slow check would make it repeat at once.
    @Test func repeatDelayStartsAfterASlowCheck() async throws {
        let probe = Probe()
        var times: [ContinuousClock.Instant] = []
        let command = Command.repeatingWhileHeld("test.track", "Track", scope: .trackUnderVoiceOverCursor, triggers: [.key("Ctrl+Cmd+Right")]) { @MainActor _ in
            times.append(.now)
        }
        let engine = trackEngine(probe, [command])
        engine.keyRepeat = { KeyRepeat(delay: .milliseconds(150), interval: .seconds(10)) { _ in true } }
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        try await Task.sleep(for: .milliseconds(300))
        probe.resolve(a)
        while times.count < 2 { try await Task.sleep(for: .milliseconds(10)) }
        engine.dispatch(key, .released, in: mix)
        await engine.waitUntilIdle()
        #expect(times[1] - times[0] >= .milliseconds(120))
    }

    /// A key let go during the cursor check was tapped: a tap-or-hold command runs its tap, and a repeating one runs once. The physical key check here reports the key down, so only the release event can tell.
    @Test(arguments: [Kind.tapOrHold, .repeating]) func releaseDuringTheCheckIsATap(_ kind: Kind) async {
        let probe = Probe()
        let engine = engine(probe, kind)
        engine.keyRepeat = { KeyRepeat(delay: .milliseconds(5), interval: .milliseconds(5)) { _ in true } }
        engine.holdTime = .zero
        engine.dispatch(key, .pressed, in: mix)
        await probe.waitForRequest()
        engine.dispatch(key, .released, in: mix)
        probe.resolve(a)
        await engine.waitUntilIdle()
        #expect(probe.events == [(kind == .tapOrHold ? "tap " : "run ") + a.name])
    }

    /// A removed strip's element can no longer be read, so the command fails rather than looking the name up again, which could find a strip recreated with that name.
    @Test func removedAcceptedTrackThrows() async {
        // No process has this ID, so reads of the element fail as they do for a removed strip.
        await #expect(throws: FloError.self) { try await Self.target(inProcess: 99_999).track(in: .mix) }
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
