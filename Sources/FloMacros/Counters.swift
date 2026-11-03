import FloEngine
import FloProTools
import FloSystem

/// Flo Tools macros for the Edit window's counters and time values: the main and sub counters, the edit selection, pre- and post-roll, nudge, grid, tempo and the selected MIDI note. They speak a value in words, open it for typing, open its selector menu, or step the grid or nudge value.
enum Counters {
    @MainActor
    static var macros: [Macro] { [
        speakEdit("floTools.speakEditMainCounter", "Speak/Edit main counter", key: "Cmd+F4", counter("Main Counter"), .position, label: ". main.", prompts: Prompts(time: "Press Delete, then type Main Counter value", other: "Type main counter value")),
        speakEdit("floTools.speakEditSubCounter", "Speak/Edit Sub Counter", key: "Cmd+F6", counter("Sub Counter"), .position, label: ". Sub.", prompts: Prompts(time: "Press Delete, then type Sub Counter value", other: "Type sub counter value.")),
        speakEdit("floTools.speakEditSelectionStart", "speak/Edit selection start", key: "Cmd+F1", counter("Edit Selection Start"), .position, label: ". start.", prompts: Prompts(time: "Press delete, then type Start value", other: "Type start value")),
        speakEdit("floTools.speakEditSelectionEnd", "Speak/Edit Selection End", key: "Cmd+F2", counter("Edit Selection End"), .position, label: ". end", prompts: Prompts(time: "Press Delete, then type End value", other: "Type end value")),
        speakEdit("floTools.speakEditSelectionLength", "Speak/Edit Selection Length", key: "Cmd+F3", counter("Edit Selection Length"), .duration, label: ". length.", prompts: Prompts(time: "Press Delete, then type Length value", other: "Type length value")),
        speakEdit("floTools.speakEditPreRollAmount", "Speak/Edit Pre-Roll Amount", key: "Cmd+F9", transport("Pre-roll Amount"), .duration, label: ". Pre-Roll Amount.", prompts: Prompts(time: "Press Delete, then type Pre-Roll amount", other: "Type Pre-Roll Amount.")),
        speakEdit("floTools.speakEditPostRollAmount", "Speak/Edit Post-Roll Amount", key: "Cmd+F10", transport("Post-roll Amount"), .duration, label: ". Post-Roll Amount.", prompts: Prompts(time: "Press Delete, then type Post-Roll amount", other: "Type Post-Roll Amount.")),
        speakEdit("floTools.speakEditNudgeValue", "Speak/Edit Nudge Value", key: "Cmd+F7", nudgeValue, .duration, label: ". Nudge.", prompts: Prompts(time: "Press Delete, then type Nudge value", other: "Type nudge value.")),
        speakEditTempo,
        speakEdit("floTools.speakEditPitchForSelectedNote", "Speak/Edit Pitch for Selected Note", key: "Opt+P", counter("MIDI Note Pitch"), .notePitch, label: ". Pitch", prompts: Prompts("Type note pitch")),
        speakEdit("floTools.speakEditAttackVelocityForSelectedNote", "Speak/Edit Attack Velocity for Selected Note", key: "Opt+A", counter("MIDI Note Attack Velocity"), .asShown, label: ". Attack", prompts: Prompts("Type attack velocity")),
        speakEdit("floTools.speakEditReleaseVelocityForSelectedNote", "Speak/Edit Release Velocity for Selected Note", key: "Opt+E", counter("MIDI Note Release Velocity"), .asShown, label: ". Release", prompts: Prompts("Type release velocity")),
        Macro("floTools.speakGridValue", "Speak Grid Value", group: .floTools, triggers: [.key("Cmd+F8")]) { _ in
            try await VoiceOver.say(read(gridValue, .duration) + ". grid.")
        },
        openMenu("floTools.selectMainCounter", "Select main counter", key: "Opt+Cmd+F4", EditWindowControl([counterCluster], role: "AXButton", .is("Main Counter selector"))),
        openMenu("floTools.selectSubCounter", "Select Sub Counter", key: "Opt+Cmd+F6", EditWindowControl([counterCluster], role: "AXButton", .is("Sub Counter selector"))),
        openMenu("floTools.selectNudgeValue", "Select Nudge Value", key: "Opt+Cmd+F7", EditWindowControl([gridNudgeCluster], role: "AXPopUpButton", .is("Nudge value"))),
        openMenu("floTools.selectGridValue", "Select Grid Value", key: "Opt+Cmd+F8", gridValue),
        step("floTools.increaseGridValue", "Increase Grid Value", key: "Ctrl+Opt+Keypad +", sends: "Shift+=", gridValue, label: ". Grid."),
        step("floTools.increaseGridValueWithQwerty", "Increase Grid Value with Qwerty", key: "Shift+=", sends: "Shift+=", gridValue, label: ". Grid."),
        step("floTools.decreaseGridValue", "Decrease Grid Value", key: "Ctrl+Opt+Keypad -", sends: "Shift+-", gridValue, label: ". Grid."),
        step("floTools.decreaseGridValueWithQwerty", "Decrease Grid Value with Qwerty", key: "Shift+-", sends: "Shift+-", gridValue, label: ". Grid."),
        step("floTools.increaseNudgeValue", "Increase Nudge Value", key: "Opt+Cmd+Keypad +", sends: "Opt+Cmd+Keypad +", nudgeValue, label: ". Nudge."),
        step("floTools.increaseNudgeValueWithQwerty", "Increase Nudge Value With Qwerty", key: "Opt+Shift+=", sends: "Opt+Shift+=", nudgeValue, label: ". Nudge."),
        step("floTools.decreaseNudgeValue", "Decrease Nudge Value", key: "Opt+Cmd+Keypad -", sends: "Opt+Cmd+Keypad -", nudgeValue, label: ". Nudge."),
        step("floTools.decreaseNudgeValueWithQwerty", "Decrease Nudge Value with Qwerty", key: "Opt+Shift+-", sends: "Opt+Shift+-", nudgeValue, label: ". Nudge."),
    ] }

    // MARK: Where the values are

    private static let counterCluster = "Counter Display Cluster"
    private static let gridNudgeCluster = "Grid/Nudge Cluster"

    private static func counter(_ name: String) -> EditWindowControl {
        EditWindowControl([counterCluster], role: "AXTextField", .is(name))
    }

    private static func transport(_ name: String) -> EditWindowControl {
        EditWindowControl(["Transport View Cluster", "Transport Display"], role: "AXTextField", .is(name))
    }

    private static let nudgeValue = EditWindowControl([gridNudgeCluster], role: "AXTextField", .is("Nudge Custom Value"))
    private static let gridValue = EditWindowControl([gridNudgeCluster], role: "AXPopUpButton", .is("Grid Value"))
    private static let tempoValue = EditWindowControl(["MIDI Control Cluster"], role: "AXTextField", .is("Tempo value"))

    // MARK: Macros

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
    private static func speakEdit(_ id: MacroID, _ name: String, key: String, _ control: EditWindowControl, _ format: CounterText.Format, label: String, prompts: Prompts) -> Macro {
        Macro(id, name, group: .floTools, triggers: [.key(key)], single: { _ in
            try await VoiceOver.say(read(control, format) + label)
        }, double: { _ in
            let value = try await openForTyping(control)
            try await VoiceOver.say(value.contains(".") ? prompts.time : prompts.other)
        })
    }

    @MainActor
    private static var speakEditTempo: Macro {
        Macro("floTools.speakEditTempo", "Speak/Edit Tempo", group: .floTools, triggers: [.key("Cmd+F11")], single: { _ in
            let app = try ProToolsApp.running()
            let tempo = try await app.element(tempoValue).value ?? ""
            try await VoiceOver.say(tempo.trimmingCharacters(in: .whitespaces) + ": Tempo")
        }, double: { _ in
            _ = try await openForTyping(tempoValue)
            try await VoiceOver.say("Type a Tempo value.")
        })
    }

    /// Presses a counter selector or a value pop-up button, which opens its menu for VoiceOver to read.
    @MainActor
    private static func openMenu(_ id: MacroID, _ name: String, key: String, _ control: EditWindowControl) -> Macro {
        Macro(id, name, group: .floTools, triggers: [.key(key)]) { _ in
            try await ProToolsApp.running().element(control).pressOpeningMenu()
        }
    }

    /// Sends Pro Tools its own key for the next or previous grid or nudge value, then speaks the new value. As in the JXA, nothing is spoken while a text field has the keyboard focus or a dialog is in front, where the key is typed or does something else.
    @MainActor
    private static func step(_ id: MacroID, _ name: String, key: String, sends: String, _ control: EditWindowControl, label: String) -> Macro {
        let combo = KeyCombo(sends)!
        return Macro(id, name, group: .floTools, triggers: [.key(key)]) { _ in
            let app = try ProToolsApp.running()
            let speaks = try await !app.keysGoToTextOrDialog()
            let before = speaks ? try await app.element(control).value ?? "" : ""
            await app.keystroke(combo)
            guard speaks else { return }
            let after = try await ProToolsUpdate.reading(changedFrom: before) { try app.element(control).value ?? "" }
            try await VoiceOver.say(CounterText.spoken(after, as: .duration) + label)
        }
    }

    // MARK: Steps

    private static func read(_ control: EditWindowControl, _ format: CounterText.Format) async throws -> String {
        let value = try await ProToolsApp.running().element(control).value ?? ""
        return CounterText.spoken(value, as: format)
    }

    /// Clicks the field so the next typed digits replace its value, and returns the value it had.
    @AccessibilityActor
    private static func openForTyping(_ control: EditWindowControl) throws -> String {
        let field = try ProToolsApp.running().element(control)
        let value = try field.value ?? ""
        try field.press()
        return value
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
            if let range = text.range(of: mark) { text.replaceSubrange(range, with: words) }
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
