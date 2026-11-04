import FloEngine
import FloProTools
import FloSystem

/// The MIDI event columns: Opt+Shift+] and Opt+Shift+[ move between the selected note's start, pitch, attack velocity, release velocity, length and end, each shown in the Edit window's Counter Display Cluster, and watch the current one, speaking it whenever it changes, for example while the user moves between notes. Ctrl+Cmd+Return opens the current one for typing.
///
/// The KM version kept the column in the variable FTEventIndex, and the Report macro ran one of six Monitor macros, each polling while FTEventIndex still had its number. Here one watch follows the column.
enum MidiEvents {
    /// The one watch, keyed by this ID because both column commands start it.
    static let watch: CommandID = "floTools.report"

    @MainActor
    static func commands(_ cursor: EventColumnCursor) -> [Command] {
        [
            Command("floTools.nextColumn", "Next Column", summary: "Moves to the next value of the selected MIDI note (start, pitch, attack velocity, release velocity, length, end; it begins on start) and speaks it, and again each time it changes. Says \"End\" after the last one.", scope: .anyProToolsWindow, triggers: [.key("Opt+Shift+]")]) { run in
                guard let column = await cursor.next() else {
                    try await VoiceOver.say("End")
                    return
                }
                await startWatch(column, in: run.engine)
            },
            Command("floTools.previousColumn", "Previous Column", summary: "Moves to the previous value of the selected MIDI note and speaks it, and again each time it changes. Before the first one, stops speaking changes and says \"No report\".", scope: .anyProToolsWindow, triggers: [.key("Opt+Shift+[")]) { run in
                guard let column = await cursor.previous() else {
                    await run.engine.watches.stop(watch)
                    try await VoiceOver.say("No report")
                    return
                }
                await startWatch(column, in: run.engine)
            },
            Command("floTools.editEvent", "Edit Event", summary: "Opens the MIDI note value that Next Column and Previous Column moved to, start at first, for typing, and says what to type.", scope: .anyProToolsWindow, triggers: [.key("Ctrl+Cmd+Return")]) { _ in
                // Before the first column there is nothing to edit, and the JXA said nothing.
                guard let column = await cursor.column else { return }
                _ = try await ProToolsApp.running().openForTyping(column.control)
                try await VoiceOver.say(column.typingPrompt)
            },
        ]
    }

    /// One of the six values, in the order the columns are walked.
    enum Column: Int, CaseIterable, Sendable {
        case start, pitch, attack, release, length, end

        var control: EditWindowControl {
            switch self {
            case .start: .selectionStart
            case .pitch: .notePitch
            case .attack: .attackVelocity
            case .release: .releaseVelocity
            case .length: .selectionLength
            case .end: .selectionEnd
            }
        }

        /// For the log.
        var fieldName: String { control.name.text }

        /// The value in words and the column's name, as each Monitor macro spoke it. An empty velocity or pitch, with no note selected, is "No".
        func spoken(_ value: String) -> String {
            let text = CounterText.spoken(value, for: control)
            return switch self {
            case .start: text + ". start."
            case .pitch: text.orIfEmpty("No") + ". Pitch"
            case .attack: text.orIfEmpty("no") + ". Attack"
            case .release: text.orIfEmpty("No") + ". Release"
            case .length: text + ". length."
            case .end: text + ". End."
            }
        }

        var typingPrompt: String {
            switch self {
            case .start: "Type start value."
            case .pitch: "Type pitch value."
            case .attack: "Type Attack velocity value."
            case .release: "Type Release value."
            case .length: "Type length value."
            case .end: "Type end value."
            }
        }
    }

    /// Replaces the watch with one for `column`.
    @MainActor
    private static func startWatch(_ column: Column, in engine: Engine) {
        engine.watches.stop(watch)
        engine.watches.toggle(watch) { await follow(column) }
    }

    /// How many reads a kept field serves before it is found again: one second of polls.
    static let readsPerLookup = 10

    /// Speaks the value now, then each change, until the watch is replaced or stopped. A failed read, for example while the Edit window is closed or no note is selected, counts as an empty value at first and is skipped later, as in the JXA. The first failure of a streak and the recovery go to the log, as in the meter watch.
    /// The field is kept between polls, so most polls are one read. It is found again after a failed read, and after `readsPerLookup` reads, because it is not known whether a field of a closed window or an old session always fails to read: a stale one is used for at most a second. Runs on `AccessibilityActor`, which owns the element, and leaves it free between polls.
    @AccessibilityActor
    private static func follow(_ column: Column) async {
        var field: AXElement?
        var reads = 0
        func read() throws -> String {
            do {
                if reads == readsPerLookup { field = nil }
                if field == nil { reads = 0 }
                let found = try field ?? ProToolsApp.running().element(column.control)
                field = found
                reads += 1
                return try found.value ?? ""
            } catch {
                field = nil
                throw error
            }
        }
        var last = ""
        var streak = ReadFailureStreak(reading: column.fieldName)
        do {
            last = try read()
        } catch {
            streak.failed(error)
        }
        await VoiceOver.sayOrLog(column.spoken(last))
        while await Watches.waitForNextPoll() {
            let now: String
            do {
                now = try Log.$skipsDebug.withValue(true) { try read() }
            } catch {
                streak.failed(error)
                continue
            }
            streak.succeeded()
            guard now != last else { continue }
            last = now
            await VoiceOver.sayOrLog(column.spoken(now))
        }
    }
}

/// Which event column the column commands are on: one of the six, or nil before the first ("No report"). Starts on the first, as the KM variable did once Cleanup Variables deleted it.
actor EventColumnCursor {
    private(set) var column: MidiEvents.Column? = .start

    func reset() { column = .start }

    /// Moves right; nil at the last column, where the cursor stays.
    func next() -> MidiEvents.Column? {
        guard let column else {
            self.column = .start
            return .start
        }
        guard let next = MidiEvents.Column(rawValue: column.rawValue + 1) else { return nil }
        self.column = next
        return next
    }

    /// Moves left; nil when the cursor ends up, or already was, before the first column.
    func previous() -> MidiEvents.Column? {
        guard let column else { return nil }
        self.column = MidiEvents.Column(rawValue: column.rawValue - 1)
        return self.column
    }
}
