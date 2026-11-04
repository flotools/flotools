import CoreGraphics
import FloEngine
import FloProTools
import FloSystem

/// Plug-in window keys: presets, bypass and parameters of the plug-in window, including the user's plug-in views (`PlugInView`). The preset commands are in `Presets`, shared with the AudioSuite window.
enum PlugIns {
    /// Spoken when the plug-in monitor cannot start or stops by itself, as in the JXA.
    private static let monitorOffText = "Plugin monitor off"

    static let loadDefaultView: CommandID = "plugin.loadPluginParametersForDefaultView"
    static let monitor: CommandID = "plugin.togglePluginMonitor"

    @MainActor
    static func commands(_ cursor: PlugInViewCursor) -> [Command] {
        Presets.commands(.plugIn) + [
            speakToggleBypass,
            toggleMonitor,
            moveParameter("plugin.nextRowParameter", "Next Row Parameter", "next row", key: "Ctrl+Down", rows: 1, columns: 0, cursor),
            moveParameter("plugin.previousRowParameter", "Previous Row Parameter", "previous row", key: "Ctrl+Up", rows: -1, columns: 0, cursor),
            moveParameter("plugin.nextColumnParameter", "Next Column Parameter", "next column", key: "Ctrl+Right", rows: 0, columns: 1, cursor),
            moveParameter("plugin.previousColumnParameter", "Previous Column Parameter", "previous column", key: "Ctrl+Left", rows: 0, columns: -1, cursor),
            stepParameter("plugin.increaseParameter", "Increase Parameter", "up", key: "Ctrl+Cmd+Up", .increase, cursor),
            stepParameter("plugin.decreaseParameter", "Decrease Parameter", "down", key: "Ctrl+Cmd+Down", .decrease, cursor),
            loadView(nil, cursor),
            displayViewTemplate,
        ] + (1...9).map { loadView($0, cursor) }
    }

    // MARK: Bypass

    static func bypassText(_ isBypassed: Bool) -> String { isBypassed ? "On" : "Off" }

    /// Single press speaks whether the plug-in is bypassed ("On" or "Off"); double press switches it and speaks the new state.
    @MainActor
    static var speakToggleBypass: Command {
        Command("plugin.speakToggleBypass", "Speak/Toggle Bypass", summary: "Single press speaks whether the plug-in is bypassed; double press switches bypass and speaks the new state.", scope: .windows([.plugIn]), triggers: [.key("Opt+B")], single: { _ in
            let bypassed = try await ProToolsApp.running().plugInWindow(.plugIn).isBypassed
            try await VoiceOver.say(bypassText(bypassed))
        }, double: { _ in
            let bypassed = try await ProToolsApp.running().plugInWindow(.plugIn).toggleBypass()
            try await VoiceOver.say(bypassText(bypassed))
        })
    }

    // MARK: Plug-in monitor

    /// "value: name", as the JXA monitor spoke a changed parameter.
    static func changeText(_ parameter: PlugInWindow.Parameter) -> String { "\(parameter.value): \(parameter.name)" }

    /// The parameters in `now` whose value differs from the same parameter in `last`, in `now`'s order. A parameter is matched by name, and a repeated name by which occurrence it is, so parameters with distinct names that move or appear are not read as changes; position-wise comparison reported every shifted one. Controls that share a name and swap places, or another plug-in reusing a name, can still count as changes. A parameter new in `now` only sets its baseline.
    static func changedParameters(from last: [PlugInWindow.Parameter], to now: [PlugInWindow.Parameter]) -> [PlugInWindow.Parameter] {
        struct Key: Hashable { let name: String, occurrence: Int }
        func keyed(_ parameters: [PlugInWindow.Parameter]) -> [(key: Key, parameter: PlugInWindow.Parameter)] {
            var seen: [String: Int] = [:]
            return parameters.map { parameter in
                let occurrence = seen[parameter.name, default: 0]
                seen[parameter.name] = occurrence + 1
                return (Key(name: parameter.name, occurrence: occurrence), parameter)
            }
        }
        let before = Dictionary(uniqueKeysWithValues: keyed(last).map { ($0.key, $0.parameter.value) })
        return keyed(now).compactMap { entry in
            guard let old = before[entry.key], old != entry.parameter.value else { return nil }
            return entry.parameter
        }
    }

    /// Starts or stops a watch of the plug-in window's parameters that speaks each one that changes, for example while automation plays. It ends by itself when the window closes.
    @MainActor
    static var toggleMonitor: Command {
        Command(monitor, "Toggle Plugin Monitor", summary: "Starts or stops a watch that speaks each plug-in parameter shown as a slider that changes, for example while automation plays. It stops by itself when the window closes or its parameters cannot be read.", scope: .windows([.plugIn]), triggers: [.key("Opt+/")]) { run in
            let watches = await run.engine.watches
            if await watches.isRunning(monitor) {
                await watches.stop(monitor)
                try await VoiceOver.say("Deactivate plugin monitor.")
                return
            }
            let window: PlugInWindow
            let first: [PlugInWindow.Parameter]
            let title: String
            do {
                window = try await ProToolsApp.running().plugInWindow(.plugIn)
                first = try await window.parameters()
                title = try await window.title
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                Log.info(.engine, "plug-in monitor could not start: \(error)")
                try await VoiceOver.say(monitorOffText)
                return
            }
            // Not running, as checked above: runs are serial, and a watch only ends by itself.
            await watches.toggle(monitor) { await watch(window, from: first) }
            try await VoiceOver.say("Watching " + title)
        }
    }

    /// Reads the parameters every `Watches.pollInterval` until cancelled, speaking each changed one. A failed read, usually the window closing, ends the watch with "Plugin monitor off", as in the JXA.
    private static func watch(_ window: PlugInWindow, from first: [PlugInWindow.Parameter]) async {
        var last = first
        while await Watches.waitForNextPoll() {
            do {
                let now = try await Log.$skipsDebug.withValue(true) { try await window.parameters() }
                for changed in changedParameters(from: last, to: now) {
                    await VoiceOver.sayOrLog(changeText(changed))
                }
                last = now
            } catch {
                Log.info(.engine, "plug-in monitor ends: \(error)")
                await VoiceOver.sayOrLog(monitorOffText)
                return
            }
        }
    }

    // MARK: Plug-in views

    /// Load Plugin Parameters for Default View (Cmd+0, and whenever a plug-in window comes to front) and for View 1 to 9 (Cmd+1 to Cmd+9): reads the plug-in's view file, speaks "<view> view for <plug-in>" and clicks the view's click point. Without a file the cursor is emptied silently, as in the JXA. The plug-in is spoken by its real name; the JXA spoke the file name form, with the first "/" as a space.
    @MainActor
    static func loadView(_ number: Int?, _ cursor: PlugInViewCursor) -> Command {
        let id = number.map { CommandID("plugin.loadPluginParametersForView\($0)") } ?? loadDefaultView
        let name = "Load Plugin Parameters for " + (number.map { "View \($0)" } ?? "Default View")
        let file = number.map { "view \($0)" } ?? "the default view"
        let summary = "Loads \(file) from the plug-in's view file in the Plug-In Views folder, speaks its name and clicks the point the view names, such as its tab; without a file it is silent." + (number == nil ? " Also runs when a plug-in window comes to the front." : "")
        return Command(id, name, summary: summary, scope: .windows([.plugIn]), triggers: [.key("Cmd+\(number ?? 0)")]) { _ in
            let proTools = try ProToolsApp.running()
            let window = try await proTools.plugInWindow(.plugIn)
            let plugIn = try await window.plugInName
            let view: PlugInView?
            do {
                view = try PlugInView.load(plugIn: plugIn, view: number)
            } catch {
                await cursor.clear()
                throw error
            }
            await cursor.load(view, for: plugIn)
            guard let view else {
                Log.info(.engine, "no view file \(PlugInView.fileName(plugIn: plugIn, view: number))")
                return
            }
            try await VoiceOver.say("\(view.name) view for \(plugIn)")
            if let click = view.click {
                try await Mouse.click(at: try await window.origin.offset(by: click), ifFront: proTools.pid)
            }
        }
    }

    /// Moves the parameter cursor, speaks "name: value" (just the name when the plug-in shows no slider of that name), and moves the mouse over the control.
    @MainActor
    static func moveParameter(_ id: CommandID, _ name: String, _ place: String, key: String, rows: Int, columns: Int, _ cursor: PlugInViewCursor) -> Command {
        Command(id, name, summary: "Moves to the parameter in the \(place) of the loaded plug-in view, speaks its name and value, and moves the mouse over its control. A parameter that is not a slider is spoken by name only, and one without a position leaves the mouse alone.", scope: .windows([.plugIn]), triggers: [.key(key)]) { _ in
            let proTools = try ProToolsApp.running()
            let window = try await proTools.plugInWindow(.plugIn)
            let parameter = try await cursor.move(for: try await window.plugInName, rows: rows, columns: columns)
            // Nil when the plug-in has no slider of that name; a failed read throws to the engine.
            let value = try await window.parameterValue(named: parameter.name)
            try await VoiceOver.say(value.map { "\(parameter.name): \($0)" } ?? parameter.name)
            // (0, 0) is the template's placeholder for a control not placed yet; moving there would only put the pointer on the window's corner.
            if parameter.point != .zero {
                try Mouse.move(to: try await window.origin.offset(by: parameter.point), ifFront: proTools.pid)
            }
        }
    }

    /// Steps the parameter the cursor is on and speaks its new value, like the Inspector's volume keys; held, it keeps stepping.
    @MainActor
    static func stepParameter(_ id: CommandID, _ name: String, _ direction: String, key: String, _ step: SliderStep, _ cursor: PlugInViewCursor) -> Command {
        Command.repeatingWhileHeld(id, name, summary: "Moves the parameter chosen with the view keys one step \(direction) and speaks its new value. Works for parameters the plug-in shows as sliders.", scope: .windows([.plugIn]), triggers: [.key(key)]) { _ in
            let window = try await ProToolsApp.running().plugInWindow(.plugIn)
            let parameter = try await cursor.current(for: try await window.plugInName)
            try await VoiceOver.say(window.stepParameter(named: parameter.name, step))
        }
    }

    /// A status menu item: shows a view file template for the front plug-in, listing its parameters, for the user to arrange and save in the Plug-In Views folder.
    @MainActor
    static var displayViewTemplate: Command {
        Command("plugin.displayPluginViewTemplate", "Display Plugin View Template", summary: "Shows a view file template that lists the front plug-in's parameters shown as sliders, to arrange and save in the Plug-In Views folder.", scope: .windows([.plugIn]), triggers: [.statusMenu]) { _ in
            let window = try await ProToolsApp.running().plugInWindow(.plugIn)
            let plugIn = try await window.plugInName
            let names = try await window.parameters().map(\.name)
            await TextWindow.show(title: "Plug-in View Template", text: PlugInView.template(plugIn: plugIn, parameters: names))
        }
    }
}

extension CGPoint {
    func offset(by other: CGPoint) -> CGPoint { CGPoint(x: x + other.x, y: y + other.y) }
}
