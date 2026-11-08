import ApplicationServices
import Testing
@testable import FloProTools
@testable import FloSystem

@Suite struct KeyCaptureEventsTests {
    let front: pid_t = 100
    let field = AXElementHandle(AXUIElementCreateApplication(100))

    /// While the observer moves to a new front app, the old app can still send events; they must not count for the new one.
    @Test func eventsFromAnotherAppAreIgnored() {
        var events = KeyCaptureEvents()
        events.record(.menuOpened, from: 200, front: front)
        events.record(.selectedTextChanged(field), from: 200, front: front)
        #expect(events.menuOpenedPid == 0)
        #expect(events.counter(of: front) == nil)
        #expect(events.revision == 0)
    }

    @Test func menuAndFieldFollowTheirNotifications() {
        var events = KeyCaptureEvents()
        events.record(.menuOpened, from: front, front: front)
        #expect(events.menuOpenedPid == front)
        events.record(.menuClosed, from: front, front: front)
        #expect(events.menuOpenedPid == 0)
        events.record(.selectedTextChanged(field), from: front, front: front)
        #expect(events.counter(of: front) != nil)
        #expect(events.counter(of: 200) == nil)
        events.record(.focusedElementChanged, from: front, front: front)
        #expect(events.counter(of: front) == nil)
    }

    /// The revision tells a check that waited on a read whether anything changed meanwhile; window events do not count.
    @Test func revisionCountsCaptureChangesOnly() {
        var events = KeyCaptureEvents()
        events.record(.windowMayHaveChanged, from: front, front: front)
        #expect(events.revision == 0)
        events.record(.menuOpened, from: front, front: front)
        events.reset()
        #expect(events.revision == 2)
        #expect(events.menuOpenedPid == 0)
    }
}

/// The check's ordering rules, with its AX and window-list reads replaced. The reads themselves were checked live (plan.md section 3).
@Suite @MainActor struct ProToolsKeyCaptureTests {
    let pid: pid_t = 100
    let field = AXElementHandle(AXUIElementCreateApplication(100))

    /// Records what the typing read was asked and runs a step during it, as a notification arriving while the read waits on Pro Tools.
    @MainActor final class TypingRead {
        var counters: [AXElementHandle?] = []
        var answer: Result<Bool, FloError> = .success(false)
        var duringRead: (@MainActor () -> Void)?

        func read(counter: AXElementHandle?) throws -> Bool {
            counters.append(counter)
            duringRead?()
            return try answer.get()
        }
    }

    func capture(popUpMenu: Bool = false, typing: TypingRead) -> ProToolsKeyCapture {
        let capture = ProToolsKeyCapture(reads: .init(
            showsPopUpMenu: { _ in popUpMenu },
            isTyping: { _, counter in try await typing.read(counter: counter) }
        ))
        capture.start()
        return capture
    }

    @Test func inactiveCaptureFindsNothing() async throws {
        let typing = TypingRead()
        typing.answer = .success(true)
        let capture = capture(typing: typing)
        capture.stop()
        #expect(try await capture.check(pid: pid) == nil)
        #expect(typing.counters.isEmpty)
    }

    @Test func menuNotificationWinsWithoutReadingTheFocus() async throws {
        let typing = TypingRead()
        let capture = capture(typing: typing)
        capture.record(.menuOpened, from: pid, front: pid)
        #expect(try await capture.check(pid: pid) == .menu)
        #expect(typing.counters.isEmpty)
        capture.record(.menuClosed, from: pid, front: pid)
        #expect(try await capture.check(pid: pid) == nil)
    }

    /// Covers a menu that opened before the observer was attached.
    @Test func popUpMenuWindowCountsAsMenu() async throws {
        #expect(try await capture(popUpMenu: true, typing: TypingRead()).check(pid: pid) == .menu)
    }

    @Test func typingCountsAsTextField() async throws {
        let typing = TypingRead()
        typing.answer = .success(true)
        #expect(try await capture(typing: typing).check(pid: pid) == .textField)
    }

    /// The remembered field is passed to the read only for its own app, and is forgotten on a focus change or a new front app.
    @Test func rememberedFieldFollowsNotifications() async throws {
        let typing = TypingRead()
        let capture = capture(typing: typing)
        capture.record(.selectedTextChanged(field), from: pid, front: pid)
        _ = try await capture.check(pid: pid)
        _ = try await capture.check(pid: 200)
        capture.record(.focusedElementChanged, from: pid, front: pid)
        _ = try await capture.check(pid: pid)
        capture.record(.selectedTextChanged(field), from: pid, front: pid)
        capture.frontAppChanged()
        _ = try await capture.check(pid: pid)
        #expect(typing.counters.map { $0 != nil } == [true, false, false, false])
    }

    /// A menu that opens while the focus is read is found by checking again.
    @Test func changeDuringTheReadChecksAgain() async throws {
        let typing = TypingRead()
        let capture = capture(typing: typing)
        typing.duringRead = { [pid] in
            typing.duringRead = nil
            capture.record(.menuOpened, from: pid, front: pid)
        }
        #expect(try await capture.check(pid: pid) == .menu)
        #expect(typing.counters.count == 1)
    }

    @Test func keepsChangingThrows() async {
        let typing = TypingRead()
        let capture = capture(typing: typing)
        typing.duringRead = { [pid, field] in capture.record(.selectedTextChanged(field), from: pid, front: pid) }
        await #expect(throws: FloError.self) { try await capture.check(pid: pid) }
        #expect(typing.counters.count == 3)
    }

    /// An unreadable focus does not show that no field is open, so the engine forwards the key.
    @Test func failedFocusReadThrows() async {
        let typing = TypingRead()
        typing.answer = .failure(.accessibility(operation: "AXFocusedUIElement", code: AXError.cannotComplete.rawValue))
        let capture = capture(typing: typing)
        await #expect(throws: FloError.self) { try await capture.check(pid: pid) }
    }
}
