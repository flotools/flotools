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

/// What starts a command. Its description is how users see it, for example "Ctrl+2" or "Flo Tools menu".
public enum Trigger: Sendable, Equatable, CustomStringConvertible {
    /// A key press. Releases end repeating and tell a tap from a hold; they start nothing.
    case hotKey(KeyCombo)
    /// The command is listed in the status menu.
    case statusMenu

    /// A hotkey written as in `KeyCombo.description`, for example `.key("Ctrl+2")`.
    public static func key(_ text: String) -> Trigger {
        .hotKey(KeyCombo(literal: text))
    }

    public var description: String {
        switch self {
        case .hotKey(let combo): "\(combo)"
        case .statusMenu: "Flo Tools menu"
        }
    }
}

/// What a command does. It is nonisolated, so it never runs on the main actor and a slow Pro Tools cannot block hotkeys: Pro Tools reads are `await`s on `AccessibilityActor`, speech is an `await` on `VoiceOverActor`, and engine state is an `await` on the main actor. A body that only changes Flo Tools state can be written `{ @MainActor run in ... }`. Throwing stops the command; the engine logs the error and says what went wrong.
public typealias CommandBody = @Sendable (CommandRun) async throws -> Void

/// When `Sound.done` plays for a hold (Tink in the JXA, which played it for a double press). Almost every JXA macro played it before the action; a few, such as Speak/Toggle Solo, played it after.
public enum DoneSoundTiming: Sendable {
    case beforeHold
    case afterHold
    /// No done sound: the hold action opens a menu that VoiceOver reads, or the command plays the sound itself.
    case none
}

public enum CommandAction: Sendable {
    case body(CommandBody)
    /// A tap and a hold of the key do different things, as Keyboard Maestro's "single press speaks, double press acts" did with two presses. Holding the key for the preferences hold time runs `hold`; letting go sooner runs `tap` at once.
    case tapOrHold(tap: CommandBody, hold: CommandBody, doneSound: DoneSoundTiming)
    /// Runs when its key is pressed and again while the key is held, at the system key repeat rate, like a held arrow key. Each run goes through the queue and the next waits for it to finish, so runs never pile up behind a busy Pro Tools. Repeating stops when the key is released or stops being a hotkey (another app in front, Flo Tools disabled or stopped), when the key is no longer down, and when a run fails or is dropped.
    case repeating(CommandBody)
}

/// A command: where it runs and what it does.
public struct Command: Sendable {
    public let id: CommandID
    /// Display name, for menus and the log.
    public let name: String
    /// What the command does, in a sentence or two for users, for `COMMANDS.md`. Every shipped command has one (`CommandReferenceTests`); test commands may leave it empty.
    public let summary: String
    /// Where its keys work.
    public let scope: Scope
    public let triggers: [Trigger]
    public let action: CommandAction

    public init(_ id: CommandID, _ name: String, summary: String = "", scope: Scope, triggers: [Trigger], body: @escaping CommandBody) {
        self.init(id, name, summary: summary, scope: scope, triggers: triggers, action: .body(body))
    }

    public init(_ id: CommandID, _ name: String, summary: String = "", scope: Scope, triggers: [Trigger], doneSound: DoneSoundTiming = .beforeHold, tap: @escaping CommandBody, hold: @escaping CommandBody) {
        self.init(id, name, summary: summary, scope: scope, triggers: triggers, action: .tapOrHold(tap: tap, hold: hold, doneSound: doneSound))
    }

    /// A command that runs again while its key is held; see `CommandAction.repeating`. A static function, because an initializer would make every trailing-closure `Command(...) { }` ambiguous.
    public static func repeatingWhileHeld(_ id: CommandID, _ name: String, summary: String = "", scope: Scope, triggers: [Trigger], body: @escaping CommandBody) -> Command {
        Command(id, name, summary: summary, scope: scope, triggers: triggers, action: .repeating(body))
    }

    private init(_ id: CommandID, _ name: String, summary: String, scope: Scope, triggers: [Trigger], action: CommandAction) {
        self.id = id
        self.name = name
        self.summary = summary
        self.scope = scope
        self.triggers = triggers
        self.action = action
    }

    /// The triggers as users see them, for example "Ctrl+2, Flo Tools menu".
    public var shortcutText: String {
        triggers.map(\.description).joined(separator: ", ")
    }

    /// Whether every word of `query` is in the name or the shortcuts, ignoring case and accents, so "solo" and "solo shift" both narrow a list. Words match anywhere, so "f1" also finds F10.
    public func matches(search query: String) -> Bool {
        let text = "\(name) \(shortcutText)"
        return query.split(whereSeparator: \.isWhitespace).allSatisfy { word in
            text.range(of: word, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    public var hotKeys: [KeyCombo] {
        triggers.compactMap { trigger in
            if case .hotKey(let combo) = trigger { return combo }
            return nil
        }
    }
}
