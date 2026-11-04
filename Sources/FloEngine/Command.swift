import FloSystem

/// The command model. Commands are declared in Swift (`FloFeatures`); the Keyboard Maestro export in `reference/` is a frozen record of what they were ported from.

/// A command's stable ID, `<group>.<command>` in lower camel case, for example "inspector.speakOpenSendB". Used for enable state, `run`, `fire` and the log; never shown to the user.
public struct CommandID: Hashable, Sendable, CustomStringConvertible, ExpressibleByStringLiteral {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public init(stringLiteral value: String) {
        self.value = value
    }

    public var description: String { value }
}

/// What starts a command.
public enum Trigger: Sendable, Equatable {
    case hotKey(KeyCombo, KeyPhase)
    /// The command is listed in the status menu.
    case statusMenu

    /// A hotkey written as in `KeyCombo.description`, for example `.key("Ctrl+2")`.
    public static func key(_ text: String, _ phase: KeyPhase = .pressed) -> Trigger {
        .hotKey(KeyCombo(literal: text), phase)
    }
}

/// What a command does. It is nonisolated, so it never runs on the main actor and a slow Pro Tools cannot block hotkeys: Pro Tools reads are `await`s on `AccessibilityActor`, speech is an `await` on `VoiceOverActor`, and engine state is an `await` on the main actor. A body that only changes Flo Tools state can be written `{ @MainActor run in ... }`. Throwing stops the command; the engine logs the error and says what went wrong.
public typealias CommandBody = @Sendable (CommandRun) async throws -> Void

/// Starts a hold when its key is pressed; returns whether it did. See `CommandAction.hold`.
public typealias HoldPress = @MainActor @Sendable (CommandRun) -> Bool
/// Ends a hold. See `CommandAction.hold`.
public typealias HoldRelease = @MainActor @Sendable (CommandRun) -> Void

/// When `Sound.done` plays for a double press (Tink in the JXA). Almost every JXA macro played it before the double action; a few, such as Speak/Toggle Solo, played it after.
public enum DoneSoundTiming: Sendable {
    case beforeDouble
    case afterDouble
    /// No done sound: the double action opens a menu that VoiceOver reads, or the command plays the sound itself.
    case none
}

public enum CommandAction: Sendable {
    case body(CommandBody)
    /// Keyboard Maestro's "single press speaks, double press acts" pattern. The engine tells the two apart with the preferences timeout.
    case singleOrDouble(single: CommandBody, double: CommandBody, doneSound: DoneSoundTiming)
    /// Changes only Flo Tools state while a key is held, like the temporary Inspector. Both closures run on the main actor as soon as the key event arrives, outside the command queue, so a busy Pro Tools cannot delay them. If `press` returns true, `release` runs when the key is released, or when the key stops being a hotkey (another app in front, Flo Tools disabled or stopped), so a hold always ends.
    case hold(press: HoldPress, release: HoldRelease)
    /// Runs when its key is pressed and again while the key is held, at the system key repeat rate, like a held arrow key. Each run goes through the queue and the next waits for it to finish, so runs never pile up behind a busy Pro Tools. Repeating stops when the key is released or stops being a hotkey (as for a hold), when the key is no longer down, and when a run fails or is dropped.
    case repeating(CommandBody)
}

/// A command: where and when it runs, and what it does.
public struct Command: Sendable {
    public let id: CommandID
    /// Display name, for menus and the log.
    public let name: String
    /// What the command does, in a sentence or two for users, for `COMMANDS.md`. Every shipped command has one (`CommandReferenceTests`); test commands may leave it empty.
    public let summary: String
    /// The windows its keys work in.
    public let scope: Scope
    /// The mode its keys need.
    public let mode: ModeCondition
    /// Off only for a command that a preference turns on, such as Toggle Temporary Inspector.
    public let enabledByDefault: Bool
    public let triggers: [Trigger]
    public let action: CommandAction

    public init(_ id: CommandID, _ name: String, summary: String = "", scope: Scope, mode: ModeCondition = .any, enabledByDefault: Bool = true, triggers: [Trigger], body: @escaping CommandBody) {
        self.init(id, name, summary: summary, scope: scope, mode: mode, enabledByDefault: enabledByDefault, triggers: triggers, action: .body(body))
    }

    public init(_ id: CommandID, _ name: String, summary: String = "", scope: Scope, mode: ModeCondition = .any, enabledByDefault: Bool = true, triggers: [Trigger], doneSound: DoneSoundTiming = .beforeDouble, single: @escaping CommandBody, double: @escaping CommandBody) {
        self.init(id, name, summary: summary, scope: scope, mode: mode, enabledByDefault: enabledByDefault, triggers: triggers, action: .singleOrDouble(single: single, double: double, doneSound: doneSound))
    }

    public init(_ id: CommandID, _ name: String, summary: String = "", scope: Scope, mode: ModeCondition = .any, enabledByDefault: Bool = true, triggers: [Trigger], press: @escaping HoldPress, release: @escaping HoldRelease) {
        self.init(id, name, summary: summary, scope: scope, mode: mode, enabledByDefault: enabledByDefault, triggers: triggers, action: .hold(press: press, release: release))
    }

    /// A command that runs again while its key is held; see `CommandAction.repeating`. A static function, because an initializer would make every trailing-closure `Command(...) { }` ambiguous.
    public static func repeatingWhileHeld(_ id: CommandID, _ name: String, summary: String = "", scope: Scope, mode: ModeCondition = .any, triggers: [Trigger], body: @escaping CommandBody) -> Command {
        Command(id, name, summary: summary, scope: scope, mode: mode, enabledByDefault: true, triggers: triggers, action: .repeating(body))
    }

    private init(_ id: CommandID, _ name: String, summary: String, scope: Scope, mode: ModeCondition, enabledByDefault: Bool, triggers: [Trigger], action: CommandAction) {
        self.id = id
        self.name = name
        self.summary = summary
        self.scope = scope
        self.mode = mode
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
