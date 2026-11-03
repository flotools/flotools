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
/// The set of registered keys changes with the front window, so a key only gets taken from other apps while a macro is active for it.
/// The app owns one instance for its lifetime; `stop()` removes every registration and the event handler.
@MainActor
public final class HotKeyCenter {
    public var handler: ((KeyCombo, KeyPhase) -> Void)?

    private var registered: [KeyCombo: (ref: EventHotKeyRef, id: UInt32)] = [:]
    private var combosByID: [UInt32: KeyCombo] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    public init() {}

    private var registeredCombos: Set<KeyCombo> { Set(registered.keys) }

    public func stop() {
        for combo in registeredCombos { unregister(combo) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        eventHandler = nil
    }

    /// Registers exactly `combos`, adding and removing registrations as needed.
    public func setActive(_ combos: Set<KeyCombo>) {
        installHandlerIfNeeded()
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

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var types = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        // The handler reaches this instance through `userData`. The app keeps the instance alive until `stop()` removes the handler.
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
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

    /// Presses and releases `combo` in app `pid` and returns once both events are posted, so the next step sees the key's effect.
    public static func press(_ combo: KeyCombo, pid: pid_t) async {
        await withCheckedContinuation { done in
            queue.async {
                pressNow(combo, pid: pid)
                done.resume()
            }
        }
    }

    /// Presses and releases `combo` in app `pid` without waiting, for the hotkey callback.
    public static func post(_ combo: KeyCombo, pid: pid_t) {
        queue.async { pressNow(combo, pid: pid) }
    }

    private static func pressNow(_ combo: KeyCombo, pid: pid_t) {
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(combo.keyCode), keyDown: down) else { continue }
            event.flags = combo.cgFlags
            event.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
            event.postToPid(pid)
            if down { usleep(holdTime) }
        }
    }
}
