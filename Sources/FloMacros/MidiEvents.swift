import FloEngine
import FloProTools
import FloSystem

/// The MIDI event columns: Opt+Shift+] and Opt+Shift+[ move between the selected note's start, pitch, attack velocity, release velocity, length and end, each shown in the Edit window's Counter Display Cluster, and watch the current one, speaking it whenever it changes, for example while the user moves between notes. Ctrl+Cmd+Return opens the current one for typing.
///
/// The KM version kept the column in the variable FTEventIndex, and the Report macro ran one of six Monitor macros, each polling while FTEventIndex still had its number. Here one watch follows the column.
enum MidiEvents {
    /// The one watch, keyed by this ID because both column macros start it.
    static let watch: MacroID = "floTools.report"

    @MainActor
    static func macros(_ cursor: EventColumnCursor) -> [Macro] {
        [
            Macro("floTools.nextColumn", "Next Column", scope: .anyProToolsWindow, triggers: [.key("Opt+Shift+]")]) { run in
                guard let column = await cursor.next() else {
                    try await VoiceOver.say("End")
                    return
                }
                await startWatch(column, in: run.engine)
            },
            Macro("floTools.previousColumn", "Previous Column", scope: .anyProToolsWindow, triggers: [.key("Opt+Shift+[")]) { run in
                guard let column = await cursor.previous() else {
                    await run.engine.monitors.stop(watch)
                    try await VoiceOver.say("No report")
                    return
                }
                await startWatch(column, in: run.engine)
            },
            Macro("floTools.editEvent", "Edit Event", scope: .anyProToolsWindow, triggers: [.key("Ctrl+Cmd+Return")]) { _ in
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
            switch self {
            case .start: CounterText.spoken(value, as: .position) + ". start."
            case .pitch: CounterText.spoken(value, as: .notePitch).orIfEmpty("No") + ". Pitch"
            case .attack: CounterText.spoken(value, as: .asShown).orIfEmpty("no") + ". Attack"
            case .release: CounterText.spoken(value, as: .asShown).orIfEmpty("No") + ". Release"
            case .length: CounterText.spoken(value, as: .duration) + ". length."
            case .end: CounterText.spoken(value, as: .position) + ". End."
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
    private static func startWatch(_ column: Column, in engine: MacroEngine) {
        engine.monitors.stop(watch)
        engine.monitors.toggle(watch) { await follow(column) }
    }

    /// How often the watch reads the value, as in the JXA.
    static let pollInterval: Duration = .milliseconds(100)

    /// Speaks the value now, then each change, until the watch is replaced or stopped. A failed read, for example while the Edit window is closed or no note is selected, counts as an empty value at first and is skipped later, as in the JXA. The first failure of a streak and the recovery go to the log, as in the meter watch.
    /// The field is found once and kept, so each poll is one read; after a failed read it is found again, because a closed window or a new session leaves the kept element invalid. Runs on `AccessibilityActor`, which owns the element, and leaves it free between polls.
    @AccessibilityActor
    private static func follow(_ column: Column) async {
        var field: AXElement?
        func read() throws -> String {
            do {
                let found = try field ?? ProToolsApp.running().element(column.control)
                field = found
                return try found.value ?? ""
            } catch {
                field = nil
                throw error
            }
        }
        var last = ""
        var failing = false
        do {
            last = try read()
        } catch {
            Log.info(.engine, "watch could not read \(column.fieldName): \(error)")
            failing = true
        }
        await VoiceOver.sayOrLog(column.spoken(last))
        while !Task.isCancelled {
            try? await Task.sleep(for: pollInterval)
            guard !Task.isCancelled else { return }
            let now: String
            do {
                now = try Log.$skipsDebug.withValue(true) { try read() }
            } catch {
                if !failing { Log.info(.engine, "watch could not read \(column.fieldName): \(error)") }
                failing = true
                continue
            }
            if failing { Log.info(.engine, "watch reads \(column.fieldName) again") }
            failing = false
            guard now != last else { continue }
            last = now
            await VoiceOver.sayOrLog(column.spoken(now))
        }
    }
}

/// Which event column the column macros are on: before the first (-1, "No report"), or one of the six. Starts on the first, as the KM variable did once Cleanup Variables deleted it.
actor EventColumnCursor {
    private var index = 0

    var column: MidiEvents.Column? { MidiEvents.Column(rawValue: index) }

    func reset() { index = 0 }

    /// Moves right; nil at the last column, where the cursor stays.
    func next() -> MidiEvents.Column? {
        guard index < MidiEvents.Column.allCases.count - 1 else { return nil }
        index += 1
        return column
    }

    /// Moves left; nil when the cursor ends up, or already was, before the first column.
    func previous() -> MidiEvents.Column? {
        guard index > -1 else { return nil }
        index -= 1
        return column
    }
}
