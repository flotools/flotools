import Carbon.HIToolbox
import CoreGraphics
import os

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

    public var description: String {
        var parts: [String] = []
        if modifiers & Self.control != 0 { parts.append("Ctrl") }
        if modifiers & Self.option != 0 { parts.append("Opt") }
        if modifiers & Self.shift != 0 { parts.append("Shift") }
        if modifiers & Self.command != 0 { parts.append("Cmd") }
        parts.append(Self.keyNames[keyCode] ?? "key\(keyCode)")
        return parts.joined(separator: "+")
    }

    static let keyNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N",
        46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`", 51: "Delete", 53: "Escape",
        65: "Keypad .", 67: "Keypad *", 69: "Keypad +", 71: "Keypad Clear", 75: "Keypad /",
        76: "Keypad Enter", 78: "Keypad -", 81: "Keypad =", 82: "Keypad 0", 83: "Keypad 1",
        84: "Keypad 2", 85: "Keypad 3", 86: "Keypad 4", 87: "Keypad 5", 88: "Keypad 6",
        89: "Keypad 7", 91: "Keypad 8", 92: "Keypad 9", 96: "F5", 97: "F6", 98: "F7",
        99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13", 106: "F16", 107: "F14",
        109: "F10", 111: "F12", 113: "F15", 114: "Help", 115: "Home", 116: "Page Up",
        117: "Forward Delete", 118: "F4", 119: "End", 120: "F2", 121: "Page Down", 122: "F1",
        123: "Left", 124: "Right", 125: "Down", 126: "Up", 64: "F17", 79: "F18", 80: "F19",
        90: "F20",
    ]
}

public enum HotKeyEvent: Sendable { case pressed, released }

/// Registers global hotkeys with Carbon `RegisterEventHotKey`, like Keyboard Maestro does.
/// The set of registered keys changes with the front window, so a key only gets taken from other apps while a macro is active for it.
@MainActor
public final class HotKeyCenter {
    public static let shared = HotKeyCenter()

    public var handler: ((KeyCombo, HotKeyEvent) -> Void)?

    private let log = Logger(subsystem: "com.chikim.FloTools", category: "hotkeys")
    private var registered: [KeyCombo: (ref: EventHotKeyRef, id: UInt32)] = [:]
    private var combosByID: [UInt32: KeyCombo] = [:]
    private var nextID: UInt32 = 1
    private var handlerInstalled = false
    private var suspended: Set<KeyCombo> = []

    public var registeredCombos: Set<KeyCombo> { Set(registered.keys) }

    /// Registers exactly `combos`, adding and removing registrations as needed.
    public func setActive(_ combos: Set<KeyCombo>) {
        installHandlerIfNeeded()
        let wanted = combos.subtracting(suspended)
        for combo in registeredCombos.subtracting(wanted) { unregister(combo) }
        for combo in wanted.subtracting(registeredCombos) { register(combo) }
    }

    /// Sends a hotkey that no macro wanted on to the front app.
    /// The key is unregistered while the copy is posted so it doesn't trigger again.
    public func passThrough(_ combo: KeyCombo) {
        guard registered[combo] != nil else { return }
        unregister(combo)
        suspended.insert(combo)
        Keyboard.press(keyCode: CGKeyCode(combo.keyCode), flags: combo.cgFlags)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            self.suspended.remove(combo)
            self.register(combo)
        }
    }

    private func register(_ combo: KeyCombo) {
        guard registered[combo] == nil else { return }
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, EventHotKeyID(signature: 0x466C_6F54, id: id), GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            log.error("could not register \(combo.description, privacy: .public): \(status)")
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

    fileprivate func dispatch(id: UInt32, event: HotKeyEvent) {
        guard let combo = combosByID[id] else { return }
        handler?(combo, event)
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var types = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr else { return status }
            let id = hotKeyID.id
            let kind: HotKeyEvent = GetEventKind(event) == UInt32(kEventHotKeyPressed) ? .pressed : .released
            MainActor.assumeIsolated { HotKeyCenter.shared.dispatch(id: id, event: kind) }
            return noErr
        }, types.count, &types, nil, nil)
    }
}

/// Synthetic keystrokes, like Keyboard Maestro's Simulate Keystroke or `System Events.keystroke`.
public enum Keyboard {
    /// Presses and releases a key. With a pid the events go straight to that app and bypass global hotkeys.
    public static func press(keyCode: CGKeyCode, flags: CGEventFlags = [], pid: pid_t? = nil) {
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: down) else { continue }
            event.flags = flags
            if let pid { event.postToPid(pid) } else { event.post(tap: .cghidEventTap) }
        }
    }

    public static func press(_ combo: KeyCombo, pid: pid_t? = nil) {
        press(keyCode: CGKeyCode(combo.keyCode), flags: combo.cgFlags, pid: pid)
    }
}
