import FloSystem

/// The macro model. Groups and macros are declared in Swift (`FloMacros`); the Keyboard Maestro export is only a porting reference, checked by `KeyboardMaestroParityTests`.

/// A macro's stable ID, `<group>.<macro>` in lower camel case, for example "inspector.speakOpenSendB". Used for enable state, `run`, preferences and the log; never shown to the user.
public struct MacroID: Hashable, Sendable, CustomStringConvertible, ExpressibleByStringLiteral {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public init(stringLiteral value: String) {
        self.value = value
    }

    public var description: String { value }
}

/// A macro group's stable ID, for example "inspector".
public struct MacroGroupID: Hashable, Sendable, CustomStringConvertible, ExpressibleByStringLiteral {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public init(stringLiteral value: String) {
        self.value = value
    }

    public var description: String { value }
}

/// A "focused window title" condition, as in Keyboard Maestro. Comparisons are case-insensitive.
public enum TitleCondition: Sendable, Equatable {
    case any
    case `is`(String)
    case contains(String)
    case matches(String)

    public func matches(_ title: String?) -> Bool {
        switch self {
        case .any:
            return true
        case .is(let text):
            return title?.caseInsensitiveCompare(text) == .orderedSame
        case .contains(let text):
            return title?.range(of: text, options: .caseInsensitive) != nil
        case .matches(let pattern):
            guard let title else { return false }
            return title.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }
}

/// A macro group: the apps it applies to and an optional window title condition.
public struct MacroGroup: Sendable, Equatable {
    public let id: MacroGroupID
    /// Display name, for menus and the log.
    public let name: String
    public let enabledByDefault: Bool
    /// Empty means the group is global.
    public let bundleIDs: [String]
    public let title: TitleCondition

    public init(_ id: MacroGroupID, name: String, enabledByDefault: Bool = true, bundleIDs: [String], title: TitleCondition = .any) {
        self.id = id
        self.name = name
        self.enabledByDefault = enabledByDefault
        self.bundleIDs = bundleIDs
        self.title = title
    }

    public func applies(to context: FrontContext) -> Bool {
        if !bundleIDs.isEmpty {
            guard let id = context.bundleID, bundleIDs.contains(id) else { return false }
        }
        return title.matches(context.windowTitle)
    }

    /// Groups with a window condition win over plain app groups when they share a hotkey.
    var specificity: Int {
        (title == .any ? 0 : 2) + (bundleIDs.isEmpty ? 0 : 1)
    }
}

public enum KeyPhase: Sendable, Equatable {
    case pressed
    /// Keyboard Maestro's "is released" fire type.
    case released
}

/// What starts a macro.
public enum MacroTrigger: Sendable, Equatable {
    case hotKey(KeyCombo, KeyPhase)
    case focusedWindow(FocusedWindowChange)
    case application(ApplicationEvent, bundleID: String)
    /// The macro is listed in the status menu.
    case statusMenu

    /// A hotkey written as in `KeyCombo.description`, for example `.key("Ctrl+2")`. An unknown key name stops the app at launch; the tests catch it first.
    public static func key(_ text: String, _ phase: KeyPhase = .pressed) -> MacroTrigger {
        guard let combo = KeyCombo(text) else { preconditionFailure("unknown key \"\(text)\"") }
        return .hotKey(combo, phase)
    }

    /// Keyboard Maestro's three focused-window triggers fire on different changes.
    public enum FocusedWindowChange: Sendable, Equatable {
        /// Another window gets focus, even one with the same title (KM `FocussedWindowChanges`).
        case focusChanges
        /// The focused title text differs, whether from a new window or a renamed one (KM `FocussedWindowTitleChanges`).
        case titleChanges
        /// The same window stays focused and its title changes (KM `FocussedWindowsTitleChanged`).
        case focusedWindowRetitled
    }

    public enum ApplicationEvent: Sendable, Equatable {
        case launched
        case quit
    }
}

/// What a macro does. It is nonisolated, so it never runs on the main actor and a slow Pro Tools cannot block hotkeys: Pro Tools reads are `await`s on `AccessibilityActor`, and speech and engine state are `await`s on the main actor. A body that only changes Flo Tools state can be written `{ @MainActor run in ... }`. Throwing stops the macro; the engine logs the error and says what went wrong.
public typealias MacroBody = @Sendable (MacroRun) async throws -> Void

/// Starts a hold when its key is pressed; returns whether it did. See `MacroAction.hold`.
public typealias HoldPress = @MainActor @Sendable (MacroRun) -> Bool
/// Ends a hold. See `MacroAction.hold`.
public typealias HoldRelease = @MainActor @Sendable (MacroRun) -> Void

/// When `Sound.done` plays for a double press (Tink in the JXA). Almost every JXA macro played it before the double action; a few, such as Speak/Toggle Solo, played it after.
public enum DoneSoundTiming: Sendable {
    case beforeDouble
    case afterDouble
}

public enum MacroAction: Sendable {
    case body(MacroBody)
    /// Keyboard Maestro's "single press speaks, double press acts" pattern. The engine tells the two apart with the preferences timeout.
    case singleOrDouble(single: MacroBody, double: MacroBody, doneSound: DoneSoundTiming)
    /// Changes only Flo Tools state while a key is held, like the temporary Inspector. Both closures run on the main actor as soon as the key event arrives, outside the macro queue, so a busy Pro Tools cannot delay them. If `press` returns true, `release` runs when the key is released, or when the key stops being a hotkey (another app in front, Flo Tools disabled or stopped), so a hold always ends.
    case hold(press: HoldPress, release: HoldRelease)
}

/// A macro: where and when it runs, and what it does.
public struct Macro: Sendable {
    public let id: MacroID
    /// Display name, for menus and the log.
    public let name: String
    public let group: MacroGroupID
    public let enabledByDefault: Bool
    public let triggers: [MacroTrigger]
    public let action: MacroAction

    public init(_ id: MacroID, _ name: String, group: MacroGroupID, enabledByDefault: Bool = true, triggers: [MacroTrigger], body: @escaping MacroBody) {
        self.init(id, name, group: group, enabledByDefault: enabledByDefault, triggers: triggers, action: .body(body))
    }

    public init(_ id: MacroID, _ name: String, group: MacroGroupID, enabledByDefault: Bool = true, triggers: [MacroTrigger], doneSound: DoneSoundTiming = .beforeDouble, single: @escaping MacroBody, double: @escaping MacroBody) {
        self.init(id, name, group: group, enabledByDefault: enabledByDefault, triggers: triggers, action: .singleOrDouble(single: single, double: double, doneSound: doneSound))
    }

    public init(_ id: MacroID, _ name: String, group: MacroGroupID, enabledByDefault: Bool = true, triggers: [MacroTrigger], press: @escaping HoldPress, release: @escaping HoldRelease) {
        self.init(id, name, group: group, enabledByDefault: enabledByDefault, triggers: triggers, action: .hold(press: press, release: release))
    }

    private init(_ id: MacroID, _ name: String, group: MacroGroupID, enabledByDefault: Bool, triggers: [MacroTrigger], action: MacroAction) {
        self.id = id
        self.name = name
        self.group = group
        self.enabledByDefault = enabledByDefault
        self.triggers = triggers
        self.action = action
    }

    public var hotKeys: [(combo: KeyCombo, phase: KeyPhase)] {
        triggers.compactMap { trigger in
            if case .hotKey(let combo, let phase) = trigger { return (combo, phase) }
            return nil
        }
    }
}
