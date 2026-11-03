extension KeyCombo {
    /// Modifier names in display order.
    static let modifierNames: [(bit: UInt32, name: String)] = [(control, "Ctrl"), (option, "Opt"), (shift, "Shift"), (command, "Cmd")]

    /// Names of macOS virtual key codes (ANSI layout). `tools/km_export.py` has the same table for the reference files.
    static let keyNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N",
        46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`", 51: "Delete", 53: "Escape",
        64: "F17", 65: "Keypad .", 67: "Keypad *", 69: "Keypad +", 71: "Keypad Clear",
        75: "Keypad /", 76: "Keypad Enter", 78: "Keypad -", 79: "F18", 80: "F19", 81: "Keypad =",
        82: "Keypad 0", 83: "Keypad 1", 84: "Keypad 2", 85: "Keypad 3", 86: "Keypad 4",
        87: "Keypad 5", 88: "Keypad 6", 89: "Keypad 7", 90: "F20", 91: "Keypad 8", 92: "Keypad 9",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13",
        106: "F16", 107: "F14", 109: "F10", 111: "F12", 113: "F15", 114: "Help", 115: "Home",
        116: "Page Up", 117: "Forward Delete", 118: "F4", 119: "End", 120: "F2", 121: "Page Down",
        122: "F1", 123: "Left", 124: "Right", 125: "Down", 126: "Up",
    ]

    private static let keyCodes = Dictionary(uniqueKeysWithValues: keyNames.map { ($0.value, $0.key) })

    /// Parses the `description` format, for example "Ctrl+Opt+Keypad -" or "Keypad +". Returns nil for unknown names.
    public init?(_ text: String) {
        var rest = Substring(text)
        var modifiers: UInt32 = 0
        for (bit, name) in Self.modifierNames where rest.hasPrefix(name + "+") && rest.count > name.count + 1 {
            modifiers |= bit
            rest = rest.dropFirst(name.count + 1)
        }
        guard let code = Self.keyCodes[String(rest)] else { return nil }
        self.init(keyCode: code, modifiers: modifiers)
    }

    /// For example "Ctrl+Opt+Keypad -".
    public var description: String {
        var parts = Self.modifierNames.filter { modifiers & $0.bit != 0 }.map(\.name)
        parts.append(Self.keyNames[keyCode] ?? "key\(keyCode)")
        return parts.joined(separator: "+")
    }
}
