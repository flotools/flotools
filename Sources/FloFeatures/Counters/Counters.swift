import FloEngine
import FloProTools
import FloSystem

/// Flo Tools commands for the Edit window's counters and time values: the main and sub counters, the edit selection, pre- and post-roll, nudge, grid, tempo and the selected MIDI note. They speak a value in words, open it for typing, open its selector menu, or step the grid or nudge value.
enum Counters {
    @MainActor
    static var commands: [Command] { [
        speakEdit("floTools.speakEditMainCounter", "Speak/Edit Main Counter", what: "main counter", key: "Cmd+F4", .mainCounter, label: ". main.", prompts: Prompts(time: "Press Delete, then type Main Counter value", other: "Type main counter value")),
        speakEdit("floTools.speakEditSubCounter", "Speak/Edit Sub Counter", what: "sub counter", key: "Cmd+F6", .subCounter, label: ". Sub.", prompts: Prompts(time: "Press Delete, then type Sub Counter value", other: "Type sub counter value.")),
        speakEdit("floTools.speakEditSelectionStart", "Speak/Edit Selection Start", what: "edit selection start", key: "Cmd+F1", .selectionStart, label: ". start.", prompts: Prompts(time: "Press delete, then type Start value", other: "Type start value")),
        speakEdit("floTools.speakEditSelectionEnd", "Speak/Edit Selection End", what: "edit selection end", key: "Cmd+F2", .selectionEnd, label: ". end", prompts: Prompts(time: "Press Delete, then type End value", other: "Type end value")),
        speakEdit("floTools.speakEditSelectionLength", "Speak/Edit Selection Length", what: "edit selection length", key: "Cmd+F3", .selectionLength, label: ". length.", prompts: Prompts(time: "Press Delete, then type Length value", other: "Type length value")),
        speakEdit("floTools.speakEditPreRollAmount", "Speak/Edit Pre-Roll Amount", what: "pre-roll amount", key: "Cmd+F9", .preRoll, label: ". Pre-Roll Amount.", prompts: Prompts(time: "Press Delete, then type Pre-Roll amount", other: "Type Pre-Roll Amount.")),
        speakEdit("floTools.speakEditPostRollAmount", "Speak/Edit Post-Roll Amount", what: "post-roll amount", key: "Cmd+F10", .postRoll, label: ". Post-Roll Amount.", prompts: Prompts(time: "Press Delete, then type Post-Roll amount", other: "Type Post-Roll Amount.")),
        speakEdit("floTools.speakEditNudgeValue", "Speak/Edit Nudge Value", what: "nudge value", key: "Cmd+F7", .nudgeValue, label: ". Nudge.", prompts: Prompts(time: "Press Delete, then type Nudge value", other: "Type nudge value.")),
        speakEdit("floTools.speakEditTempo", "Speak/Edit Tempo", what: "tempo", key: "Cmd+F11", .tempo, label: ": Tempo", prompts: Prompts("Type a Tempo value.")),
        speakEdit("floTools.speakEditPitchForSelectedNote", "Speak/Edit Pitch for Selected Note", what: "pitch of the selected MIDI note", key: "Opt+P", .notePitch, label: ". Pitch", prompts: Prompts("Type note pitch")),
        speakEdit("floTools.speakEditAttackVelocityForSelectedNote", "Speak/Edit Attack Velocity for Selected Note", what: "attack velocity of the selected MIDI note", key: "Opt+A", .attackVelocity, label: ". Attack", prompts: Prompts("Type attack velocity")),
        speakEdit("floTools.speakEditReleaseVelocityForSelectedNote", "Speak/Edit Release Velocity for Selected Note", what: "release velocity of the selected MIDI note", key: "Opt+E", .releaseVelocity, label: ". Release", prompts: Prompts("Type release velocity")),
        Command("floTools.speakGridValue", "Speak Grid Value", summary: "Speaks the grid value.", scope: .anyProToolsWindow, triggers: [.key("Cmd+F8")]) { _ in
            try await VoiceOver.say(read(.gridValue) + ". grid.")
        },
        openMenu("floTools.selectMainCounter", "Select Main Counter", what: "main counter selector", key: "Opt+Cmd+F4", .mainCounterSelector),
        openMenu("floTools.selectSubCounter", "Select Sub Counter", what: "sub counter selector", key: "Opt+Cmd+F6", .subCounterSelector),
        openMenu("floTools.selectNudgeValue", "Select Nudge Value", what: "nudge value", key: "Opt+Cmd+F7", .nudgeSelector),
        openMenu("floTools.selectGridValue", "Select Grid Value", what: "grid value", key: "Opt+Cmd+F8", .gridValue),
        step("floTools.increaseGridValue", "Increase Grid Value", what: "grid value", key: "Ctrl+Opt+Keypad +", sends: "Shift+=", .gridValue, when: .outsideDialogsAndText, label: ". Grid."),
        step("floTools.increaseGridValueWithQwerty", "Increase Grid Value with Qwerty", what: "grid value", key: "Shift+=", sends: "Shift+=", .gridValue, when: .outsideDialogsAndText, label: ". Grid."),
        step("floTools.decreaseGridValue", "Decrease Grid Value", what: "grid value", key: "Ctrl+Opt+Keypad -", sends: "Shift+-", .gridValue, when: .outsideDialogsAndText, label: ". Grid."),
        step("floTools.decreaseGridValueWithQwerty", "Decrease Grid Value with Qwerty", what: "grid value", key: "Shift+-", sends: "Shift+-", .gridValue, when: .outsideDialogsAndText, label: ". Grid."),
        step("floTools.increaseNudgeValue", "Increase Nudge Value", what: "nudge value", key: "Opt+Cmd+Keypad +", sends: "Opt+Cmd+Keypad +", .nudgeValue, when: .always, label: ". Nudge."),
        step("floTools.increaseNudgeValueWithQwerty", "Increase Nudge Value with Qwerty", what: "nudge value", key: "Opt+Shift+=", sends: "Opt+Shift+=", .nudgeValue, when: .outsideDialogsAndText, label: ". Nudge."),
        step("floTools.decreaseNudgeValue", "Decrease Nudge Value", what: "nudge value", key: "Opt+Cmd+Keypad -", sends: "Opt+Cmd+Keypad -", .nudgeValue, when: .always, label: ". Nudge."),
        step("floTools.decreaseNudgeValueWithQwerty", "Decrease Nudge Value with Qwerty", what: "nudge value", key: "Opt+Shift+-", sends: "Opt+Shift+-", .nudgeValue, when: .outsideDialogsAndText, label: ". Nudge."),
    ] }

    // MARK: Commands

    /// What the double press of Speak/Edit says after opening the value for typing: a value in minutes and seconds must be cleared first.
    struct Prompts: Sendable {
        let time: String
        let other: String

        init(time: String, other: String) {
            self.time = time
            self.other = other
        }

        /// One prompt for a field that never shows minutes and seconds.
        init(_ prompt: String) {
            self.init(time: prompt, other: prompt)
        }
    }

    /// Single press speaks the value in words followed by `label`; double press clicks the field, so typing replaces the value, and says what to type.
    @MainActor
    private static func speakEdit(_ id: CommandID, _ name: String, what: String, key: String, _ control: EditWindowControl, label: String, prompts: Prompts) -> Command {
        Command(id, name, summary: "Single press speaks the \(what) in words; double press opens it for typing a new value.", scope: .anyProToolsWindow, triggers: [.key(key)], single: { _ in
            try await VoiceOver.say(read(control) + label)
        }, double: { _ in
            let value = try await ProToolsApp.running().openForTyping(control)
            try await VoiceOver.say(value.contains(".") ? prompts.time : prompts.other)
        })
    }

    /// Presses a counter selector or a value pop-up button, which opens its menu for VoiceOver to read.
    @MainActor
    private static func openMenu(_ id: CommandID, _ name: String, what: String, key: String, _ control: EditWindowControl) -> Command {
        Command(id, name, summary: "Opens the \(what) menu.", scope: .anyProToolsWindow, triggers: [.key(key)]) { _ in
            try await ProToolsApp.running().element(control).pressOpeningMenu()
        }
    }

    /// Sends Pro Tools its own key for the next or previous grid or nudge value, then speaks the new value if the guard allows it. The KM grid and Qwerty nudge macros checked for a text field and a dialog; the keypad nudge macros did not.
    @MainActor
    private static func step(_ id: CommandID, _ name: String, what: String, key: String, sends: String, _ control: EditWindowControl, when guarding: AnnouncementGuard, label: String) -> Command {
        let combo = KeyCombo(literal: sends)
        let direction = sends.hasSuffix("-") ? "previous" : "next"
        return Command(id, name, summary: "Changes the \(what) to the \(direction) one and speaks it." + KeyAnnouncements.summaryNote(guarding), scope: .anyProToolsWindow, triggers: [.key(key)]) { run in
            try await KeyAnnouncements.announceChange(run, sending: combo, when: guarding, find: { try ProToolsApp.running().element(control) }, read: { try $0.value ?? "" }, spoken: { CounterText.spoken($0, for: control) + label })
        }
    }

    // MARK: Steps

    private static func read(_ control: EditWindowControl) async throws -> String {
        CounterText.spoken(try await ProToolsApp.running().value(of: control), for: control)
    }
}

/// Counter and time values in words, as the JXA spoke them. Pro Tools shows bars and beats as "    1| 1| 000" and minutes and seconds as "   0:00.250"; other formats, such as timecode and samples, are spoken as shown.
enum CounterText {
    enum Format {
        /// A point in the session: "Bar 1, Beat 2, Tick 240".
        case position
        /// A length: "1 bar, 2 beats, 240 ticks", or "0 ticks".
        case duration
        /// A note name such as "C#3" or "Bbb2", with its accidental in words.
        case notePitch
        /// A plain number, such as a velocity.
        case asShown
    }

    /// How each field's value is spoken, for the counter commands and the MIDI event watch alike. Selectors and other controls that are never spoken are as shown.
    static func format(of control: EditWindowControl) -> Format {
        switch control {
        case .mainCounter, .subCounter, .selectionStart, .selectionEnd: .position
        case .selectionLength, .preRoll, .postRoll, .nudgeValue, .gridValue: .duration
        case .notePitch: .notePitch
        default: .asShown
        }
    }

    /// `value` of `control` in words.
    static func spoken(_ value: String, for control: EditWindowControl) -> String {
        spoken(value, as: format(of: control))
    }

    /// Parts are joined with ", ". The JXA left a trailing ", " when the ticks were 0, and ran minutes, seconds and milliseconds together ("1 minute30 seconds", "2minutes").
    static func spoken(_ value: String, as format: Format) -> String {
        let value = value.trimmingCharacters(in: .whitespaces)
        switch format {
        case .notePitch: return notePitch(value)
        case .asShown: return value
        case .position: return time(value) { bars, beats, ticks in
            ["Bar \(bars)", "Beat \(beats)", ticks.isEmpty ? nil : "Tick \(ticks)"].compactMap { $0 }.joined(separator: ", ")
        }
        case .duration: return time(value) { bars, beats, ticks in
            let parts = [count(withoutLeadingZeros(bars), "bar"), count(withoutLeadingZeros(beats), "beat"), count(ticks, "tick")].compactMap { $0 }
            return parts.isEmpty ? "0 ticks" : parts.joined(separator: ", ")
        }
        }
    }

    /// A bars and beats value goes to `barsBeats` with the leading zeros of the ticks removed; minutes and seconds are spoken as a length for both formats, as in the JXA.
    private static func time(_ value: String, barsBeats: (_ bars: String, _ beats: String, _ ticks: String) -> String) -> String {
        let bbt = value.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        if bbt.count == 3 { return barsBeats(bbt[0], bbt[1], withoutLeadingZeros(bbt[2])) }
        let time = value.split(separator: ":")
        if time.count == 2, time[1].contains(".") { return minutesSeconds(minutes: String(time[0]), seconds: String(time[1])) }
        return value
    }

    /// Pro Tools writes accidentals as "#", "x", "b" and "bb". Like the JXA, only the first of each is replaced, double before single: "C#3" is "C-Sharp 3".
    private static func notePitch(_ value: String) -> String {
        var text = value
        for (mark, words) in [("x", "-DOUBLE Sharp"), ("#", "-Sharp "), ("bb", "-DOUBLE Flat"), ("b", "-Flat ")] {
            text = text.replacingFirst(mark, with: words)
        }
        return text
    }

    private static func minutesSeconds(minutes: String, seconds: String) -> String {
        let secondParts = seconds.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let parts = [
            count(withoutLeadingZeros(minutes), "minute"),
            count(withoutLeadingZeros(secondParts[0]), "second"),
            secondParts.count > 1 ? count(withoutLeadingZeros(secondParts[1]), "millisecond") : nil,
        ].compactMap { $0 }
        return parts.isEmpty ? "0 seconds" : parts.joined(separator: ", ")
    }

    /// "1 bar", "2 bars"; nil for an empty count, which means 0.
    private static func count(_ number: String, _ unit: String) -> String? {
        guard !number.isEmpty else { return nil }
        return number == "1" ? "1 \(unit)" : "\(number) \(unit)s"
    }

    private static func withoutLeadingZeros(_ number: String) -> String {
        String(number.drop { $0 == "0" })
    }
}
