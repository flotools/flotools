import FloEngine
import FloProTools
import FloSystem

/// Inspector macros for the level and gain reduction meters of the track under the VoiceOver cursor. A double press starts or stops a watch (`Monitors`) that follows the VoiceOver cursor from track to track and reports meter changes until stopped.
enum InspectorMeters {
    @MainActor
    static var macros: [Macro] {
        // Shared by the gain reduction watch, which records the deepest reading, and Speak Gain Reduction Meter Maximum Value, which reports it. The KM version kept it in the FTGRMax variable.
        let deepest = GainReductionPeak()
        return [level, gainReduction(deepest), speakGainReductionMaximum(deepest)]
    }

    static let levelMacro: MacroID = "inspector.speakLevelMeterToggleLevelMeterMonitor"
    static let gainReductionMacro: MacroID = "inspector.speakGainReductionMeterToggleGainReductionMeterMonitor"

    /// Stops both meter watches, like the KM Deactivate Level and Gain Reduction Monitors macro when the Pro Tools window changes.
    @MainActor
    static func stopWatches(in engine: MacroEngine) {
        engine.monitors.stop(levelMacro)
        engine.monitors.stop(gainReductionMacro)
    }

    // MARK: Level meter

    /// Speak Level Meter, Toggle Level Meter Monitor: single press speaks the level or "No Signal"; double press starts or stops a watch that speaks each new level.
    @MainActor
    static var level: Macro {
        Macro(levelMacro, "Speak Level Meter, Toggle Level Meter Monitor", group: .inspector, triggers: [.key("L")], single: { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor()
            try await VoiceOver.say(reading(.level, of: track).orIfEmpty("No Signal"))
        }, double: { run in
            let app = try ProToolsApp.running()
            await toggleWatch(run, started: "Watching level meter", stopped: "Deactivate level monitor") {
                await watch(.level, in: app) { value in
                    await VoiceOver.sayOrLog(value.orIfEmpty("No Level Meter"))
                }
            }
        })
    }

    // MARK: Gain reduction meter

    /// Speak Gain Reduction Meter, Toggle Gain Reduction Meter Monitor: single press speaks the gain reduction; double press starts or stops a watch that plays the progress sound on each change and records the deepest reduction.
    @MainActor
    static func gainReduction(_ deepest: GainReductionPeak) -> Macro {
        Macro(gainReductionMacro, "Speak Gain Reduction Meter, Toggle Gain Reduction Meter Monitor", group: .inspector, triggers: [.key(";")], single: { _ in
            let track = try await ProToolsApp.running().trackUnderVoiceOverCursor()
            try await VoiceOver.say(reading(.gainReduction, of: track))
        }, double: { run in
            let app = try ProToolsApp.running()
            await toggleWatch(run, started: "Watching Gain Reduction Meter", stopped: "Deactivate Gain Reduction monitor") {
                await deepest.reset()
                await watch(.gainReduction, in: app, first: { value in await deepest.record(value) }) { value in
                    await deepest.record(value)
                    await Sound.progress.play()
                }
            }
        })
    }

    /// Speak Gain Reduction Meter Maximum Value: speaks the deepest reduction since the watch started or since the last time this was spoken, then starts over from 0, as in the JXA.
    @MainActor
    static func speakGainReductionMaximum(_ deepest: GainReductionPeak) -> Macro {
        Macro("inspector.speakGainReductionMeterMaximumValue", "Speak Gain Reduction Meter Maximum Value", group: .inspector, triggers: [.key("Shift+;")]) { _ in
            try await VoiceOver.say(String(deepest.take()))
        }
    }

    // MARK: Watching

    /// Starts the watch for the run's macro, or stops it if it runs. Says `started` when it starts; the watch says `stopped` when it ends.
    @MainActor
    private static func toggleWatch(_ run: MacroRun, started: String, stopped: String, _ body: @escaping @Sendable () async -> Void) {
        let isRunning = run.engine.monitors.toggle(run.macro.id) {
            await body()
            await VoiceOver.sayOrLog(stopped)
        }
        if isRunning { VoiceOver.sayOrLog(started) }
    }

    /// How often a watch reads the meter. The JXA level monitor waited 0.1 s between reads; its gain reduction monitor did not wait at all.
    static let pollInterval: Duration = .milliseconds(100)

    /// Reads `meter` of the track under the VoiceOver cursor every `pollInterval` until cancelled, calling `changed` with each reading that differs from the one before. Moving the cursor to another track compares with the last reading, so a different level there is reported. The first reading, and the first after a failed one, only sets the baseline (passed to `first`), as in the JXA.
    /// Failed reads are expected while the cursor is on something that is not a track or Pro Tools is busy, so they only end the current baseline; the first failure of a run of them is logged. The watch ends when Pro Tools quits.
    static func watch(_ meter: TrackStrip.Meter, in app: ProToolsApp, first: @escaping @Sendable (String) async -> Void = { _ in }, changed: @escaping @Sendable (String) async -> Void) async {
        var track: TrackStrip?
        var last: String?
        var failing = false
        while !Task.isCancelled {
            do {
                let value = try await Log.$skipsDebug.withValue(true) {
                    let name = try await VoiceOver.cursorText().required("the VoiceOver cursor")
                    let strip: TrackStrip
                    if let track, track.name == name { strip = track } else { strip = try await app.track(named: name) }
                    track = strip
                    return try await reading(meter, of: strip)
                }
                if failing { Log.info(.engine, "watch reads the meter again") }
                failing = false
                if last == nil { await first(value) } else if value != last { await changed(value) }
                last = value
            } catch {
                guard app.isRunning else {
                    Log.info(.engine, "watch ends: Pro Tools quit")
                    return
                }
                if !failing { Log.info(.engine, "watch could not read the meter: \(error)") }
                failing = true
                track = nil
                last = nil
            }
            try? await Task.sleep(for: pollInterval)
        }
    }

    @AccessibilityActor
    static func reading(_ meter: TrackStrip.Meter, of track: TrackStrip) throws -> String {
        try track.meter(meter).value ?? ""
    }
}

/// The deepest gain reduction seen, in whole dB, 0 meaning none. Gain reduction readings are negative, so deeper is smaller.
actor GainReductionPeak {
    private var deepest = 0

    func reset() { deepest = 0 }

    func record(_ reading: String) {
        guard let value = Self.decibels(reading) else { return }
        deepest = min(deepest, value)
    }

    /// The deepest reduction, and starts over from 0.
    func take() -> Int {
        defer { deepest = 0 }
        return deepest
    }

    /// Whole decibels from a meter reading such as "minus 3 db", truncated toward zero like the JXA's `parseInt`. Nil for a reading without a number.
    static func decibels(_ reading: String) -> Int? {
        let number = reading.replacingFirst(" db", with: "").replacingFirst("minus ", with: "-")
        return Double(number).map { Int($0) }
    }
}
