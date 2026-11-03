import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// A key code plus modifiers. Modifier bits are the Carbon ones, which Keyboard Maestro also uses: Cmd 256, Shift 512, Option 2048, Control 4096.
public struct KeyCombo: Hashable, Sendable, CustomStringConvertible {
    public static let command: UInt32 = 256
    public static let shift: UInt32 = 512
    public static let option: UInt32 = 2048
    public static let control: UInt32 = 4096

    public let keyCode: UInt32
    public let modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public var cgFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers & Self.command != 0 { flags.insert(.maskCommand) }
        if modifiers & Self.shift != 0 { flags.insert(.maskShift) }
        if modifiers & Self.option != 0 { flags.insert(.maskAlternate) }
        if modifiers & Self.control != 0 { flags.insert(.maskControl) }
        return flags
    }
}

public enum KeyPhase: Sendable, Equatable {
    case pressed
    /// Keyboard Maestro's "is released" fire type.
    case released
}

/// Registers global hotkeys with Carbon `RegisterEventHotKey`, like Keyboard Maestro does.
/// The set of registered keys changes with the front window, so a key only gets taken from other apps while a command is active for it.
/// The app owns one instance for its lifetime; `stop()` removes every registration and the event handler.
@MainActor
public final class HotKeyCenter {
    public var handler: ((KeyCombo, KeyPhase) -> Void)?

    private var registered: [KeyCombo: (ref: EventHotKeyRef, id: UInt32)] = [:]
    private var combosByID: [UInt32: KeyCombo] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?
    /// So a handler that cannot be installed is logged once, not on every context change.
    private var handlerFailureLogged = false

    public init() {}

    private var registeredCombos: Set<KeyCombo> { Set(registered.keys) }

    public func stop() {
        for combo in registeredCombos { unregister(combo) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        eventHandler = nil
    }

    /// Registers exactly `combos`, adding and removing registrations as needed.
    /// Without the event handler no key is registered: a registered key would be taken from Pro Tools and do nothing. The next call tries again.
    public func setActive(_ combos: Set<KeyCombo>) {
        guard installHandlerIfNeeded() else { return }
        // The engine recomputes the keys after every state change; most leave them as they were, and the full list is long.
        guard combos != registeredCombos else { return }
        for combo in registeredCombos.subtracting(combos) { unregister(combo) }
        for combo in combos.subtracting(registeredCombos) { register(combo) }
        Log.debug(.hotkeys, "registered: \(registered.keys.map(\.description).sorted().joined(separator: ", "))")
    }

    private func register(_ combo: KeyCombo) {
        guard registered[combo] == nil else { return }
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, EventHotKeyID(signature: 0x466C_6F54, id: id), GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            Log.error(.hotkeys, "could not register \(combo): OSStatus \(status)")
            return
        }
        registered[combo] = (ref, id)
        combosByID[id] = combo
    }

    private func unregister(_ combo: KeyCombo) {
        guard let entry = registered.removeValue(forKey: combo) else { return }
        UnregisterEventHotKey(entry.ref)
        combosByID[entry.id] = nil
    }

    fileprivate func dispatch(id: UInt32, phase: KeyPhase) {
        guard let combo = combosByID[id] else { return }
        handler?(combo, phase)
    }

    /// Whether the handler is installed.
    private func installHandlerIfNeeded() -> Bool {
        guard eventHandler == nil else { return true }
        var types = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        // The handler reaches this instance through `userData`. The app keeps the instance alive until `stop()` removes the handler.
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr else { return status }
            let id = hotKeyID.id
            let phase: KeyPhase = GetEventKind(event) == UInt32(kEventHotKeyPressed) ? .pressed : .released
            MainActor.assumeIsolated {
                Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue().dispatch(id: id, phase: phase)
            }
            return noErr
        }, types.count, &types, userData, &eventHandler)
        guard status == noErr, eventHandler != nil else {
            eventHandler = nil
            if !handlerFailureLogged { Log.error(.hotkeys, "could not install the hotkey handler: OSStatus \(status); no hotkeys registered") }
            handlerFailureLogged = true
            return false
        }
        if handlerFailureLogged { Log.info(.hotkeys, "hotkey handler installed after an earlier failure") }
        handlerFailureLogged = false
        return true
    }
}

/// Synthetic keystrokes, like Keyboard Maestro's Simulate Keystroke or `System Events.keystroke`.
///
/// Keys are posted to one process with `postToPid`, which does not trigger global hotkeys, so a key passed on is not caught again by Flo Tools. Presses go through one serial queue, so they arrive in order and a key down always gets its key up, even when the caller is cancelled.
public enum Keyboard {
    /// In `eventSourceUserData` of every event Flo Tools posts ("FloT"), so logs and event taps can tell them from typed keys.
    public static let syntheticMarker: Int64 = 0x466C_6F54

    /// Pro Tools ignores a key down followed at once by its key up (measured 2026-11-02 with Cmd+= posted to Pro Tools: no gap failed 3 of 3, gaps from 1 to 30 ms worked 3 of 3), so the key is held this long.
    private static let holdTime: useconds_t = 10_000
    private static let queue = DispatchQueue(label: "com.chikim.FloTools.keyboard")

    /// Presses and releases `combo` in app `pid` and returns once both events are posted, so the next step sees the key's effect. Throws `FloError.couldNot` when the events cannot be made; then nothing is posted.
    public static func press(_ combo: KeyCombo, pid: pid_t) async throws {
        let posted = await withCheckedContinuation { done in
            queue.async { done.resume(returning: pressNow(combo, pid: pid)) }
        }
        guard posted else { throw FloError.couldNot("send a key to Pro Tools") }
        // Only keys a command sends are logged here; `post`, which also passes on keys no command matched, logs none.
        Log.info(.hotkeys, "sent \(combo)")
    }

    /// Presses and releases `combo` in app `pid` without waiting, for the hotkey callback, which has no caller to report to. A failure is logged without the key, since this also passes on keys no command matched.
    public static func post(_ combo: KeyCombo, pid: pid_t) {
        queue.async {
            if !pressNow(combo, pid: pid) { Log.error(.hotkeys, "could not make keyboard events to pass a key on") }
        }
    }

    /// Waits until the user lets go of Command, Shift, Option and Control, like Keyboard Maestro's Pause Until modifiers are up, so a command's own clicks do not carry the hotkey's modifiers. Throws `FloError.couldNot` after `limit`.
    public static func waitForModifiersReleased(within limit: Duration = .seconds(10)) async throws {
        let held: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        let start = ContinuousClock.now
        while !CGEventSource.flagsState(.combinedSessionState).intersection(held).isEmpty {
            guard ContinuousClock.now - start < limit else { throw FloError.couldNot("go on while modifier keys are held down") }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    /// Both events are made before either is posted, so a key down is never left without its key up. False when they cannot be made.
    private static func pressNow(_ combo: KeyCombo, pid: pid_t) -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(combo.keyCode), keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(combo.keyCode), keyDown: false)
        else { return false }
        for event in [down, up] {
            event.flags = combo.cgFlags
            event.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
        }
        down.postToPid(pid)
        usleep(holdTime)
        up.postToPid(pid)
        return true
    }
}
