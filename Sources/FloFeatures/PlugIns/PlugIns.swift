import CoreGraphics
import FloEngine
import FloProTools
import FloSystem

/// Plug-in window keys: presets, bypass and parameters of the plug-in window, including the user's plug-in views (`PlugInView`). The preset commands are shared with the AudioSuite window.
enum PlugIns {
    static let loadDefaultView: CommandID = "plugin.loadPluginParametersForDefaultView"
    static let monitor: CommandID = "plugin.togglePluginMonitor"

    @MainActor
    static func commands(_ cursor: PlugInViewCursor) -> [Command] {
        [
            stepPreset("plugin.nextPreset", "Next Preset", .plugIn, .next, key: "]"),
            stepPreset("plugin.previousPreset", "Previous Preset", .plugIn, .previous, key: "["),
            speakChoosePreset("plugin.speakChoosePreset", "Speak/Choose Preset", .plugIn),
            speakToggleBypass,
            toggleMonitor,
            moveParameter("plugin.nextRowParameter", "Next Row Parameter", key: "Ctrl+Down", rows: 1, columns: 0, cursor),
            moveParameter("plugin.previousRowParameter", "Previous Row Parameter", key: "Ctrl+Up", rows: -1, columns: 0, cursor),
            moveParameter("plugin.nextColumnParameter", "Next Column Parameter", key: "Ctrl+Right", rows: 0, columns: 1, cursor),
            moveParameter("plugin.previousColumnParameter", "Previous Column Parameter", key: "Ctrl+Left", rows: 0, columns: -1, cursor),
            loadView(nil, cursor),
            displayViewTemplate,
        ] + (1...9).map { loadView($0, cursor) }
    }

    // MARK: Presets, shared with Audio Suite

    /// Goes to the next or previous preset and speaks its name.
    @MainActor
    static func stepPreset(_ id: CommandID, _ name: String, _ kind: PlugInWindow.Kind, _ step: PlugInWindow.PresetStep, key: String) -> Command {
        Command(id, name, scope: scope(kind), triggers: [.key(key)]) { _ in
            let preset = try await ProToolsApp.running().plugInWindow(kind).step(step)
            try await VoiceOver.say(preset)
        }
    }

    /// Single press speaks the preset; double press opens the preset menu.
    @MainActor
    static func speakChoosePreset(_ id: CommandID, _ name: String, _ kind: PlugInWindow.Kind) -> Command {
        Command(id, name, scope: scope(kind), triggers: [.key("Opt+Cmd+P")], single: { _ in
            let preset = try await ProToolsApp.running().plugInWindow(kind).preset
            try await VoiceOver.say(preset)
        }, double: { _ in
            try await ProToolsApp.running().plugInWindow(kind).openPresetMenu()
        })
    }

    private static func scope(_ kind: PlugInWindow.Kind) -> Scope {
        switch kind {
        case .plugIn: .windows([.plugIn])
        case .audioSuite: .windows([.audioSuite])
        }
    }

    // MARK: Bypass

    static func bypassText(_ isBypassed: Bool) -> String { isBypassed ? "On" : "Off" }

    /// Single press speaks whether the plug-in is bypassed ("On" or "Off"); double press switches it and speaks the new state.
    @MainActor
    static var speakToggleBypass: Command {
        Command("plugin.speakToggleBypass", "Speak/Toggle Bypass", scope: .windows([.plugIn]), triggers: [.key("Opt+B")], single: { _ in
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

    /// Starts or stops a watch of the plug-in window's parameters that speaks each one that changes, for example while automation plays. It ends by itself when the window closes.
    @MainActor
    static var toggleMonitor: Command {
        Command(monitor, "Toggle Plugin Monitor", scope: .windows([.plugIn]), triggers: [.key("Opt+/")]) { run in
            let monitors = await run.engine.monitors
            if await monitors.isRunning(monitor) {
                await monitors.stop(monitor)
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
                try await VoiceOver.say("Plugin monitor off")
                return
            }
            // Not running, as checked above: runs are serial, and a watch only ends by itself.
            await monitors.toggle(monitor) { await watch(window, from: first) }
            try await VoiceOver.say("Watching " + title)
        }
    }

    /// Reads the parameters every `Monitors.pollInterval` until cancelled, speaking each changed one. A failed read, usually the window closing, ends the watch with "Plugin monitor off", as in the JXA.
    private static func watch(_ window: PlugInWindow, from first: [PlugInWindow.Parameter]) async {
        var last = first
        while !Task.isCancelled {
            try? await Task.sleep(for: Watches.pollInterval)
            guard !Task.isCancelled else { return }
            do {
                let now = try await Log.$skipsDebug.withValue(true) { try await window.parameters() }
                for (old, new) in zip(last, now) where old != new {
                    await VoiceOver.sayOrLog(changeText(new))
                }
                last = now
            } catch {
                Log.info(.engine, "plug-in monitor ends: \(error)")
                await VoiceOver.sayOrLog("Plugin monitor off")
                return
            }
        }
    }

    // MARK: Plug-in views

    /// Load Plugin Parameters for Default View (Cmd+0, and whenever a plug-in window comes to front) and for View 1 to 9 (Cmd+1 to Cmd+9): reads the plug-in's view file, speaks "<view> view for <plug-in>" and clicks the view's click point. Without a file the cursor is emptied silently, as in the JXA.
    @MainActor
    static func loadView(_ number: Int?, _ cursor: PlugInViewCursor) -> Command {
        let id = number.map { CommandID("plugin.loadPluginParametersForView\($0)") } ?? loadDefaultView
        let name = "Load Plugin Parameters for " + (number.map { "View \($0)" } ?? "Default View")
        return Command(id, name, scope: .windows([.plugIn]), triggers: [.key("Cmd+\(number ?? 0)")]) { _ in
            let window = try await ProToolsApp.running().plugInWindow(.plugIn)
            let plugIn = try await window.plugInName
            let view: PlugInView?
            do {
                view = try PlugInView.load(plugIn: plugIn, view: number)
            } catch {
                await cursor.load(nil)
                throw error
            }
            await cursor.load(view)
            guard let view else {
                Log.info(.engine, "no view file \(PlugInView.fileName(plugIn: plugIn, view: number))")
                return
            }
            try await VoiceOver.say("\(view.name) view for \(plugIn)")
            if let click = view.click {
                try await Mouse.click(at: try await window.origin.offset(by: click))
            }
        }
    }

    /// Moves the parameter cursor, speaks "name: value" (just the name when the plug-in shows no slider of that name), and moves the mouse over the control.
    @MainActor
    static func moveParameter(_ id: CommandID, _ name: String, key: String, rows: Int, columns: Int, _ cursor: PlugInViewCursor) -> Command {
        Command(id, name, scope: .windows([.plugIn]), triggers: [.key(key)]) { _ in
            let window = try await ProToolsApp.running().plugInWindow(.plugIn)
            let parameter = try await cursor.move(rows: rows, columns: columns)
            // Nil when the plug-in has no slider of that name; a failed read throws to the engine.
            let value = try await window.parameterValue(named: parameter.name)
            try await VoiceOver.say(value.map { "\(parameter.name): \($0)" } ?? parameter.name)
            // (0, 0) is the template's placeholder for a control not placed yet; moving there would only put the pointer on the window's corner.
            if parameter.point != .zero {
                try Mouse.move(to: try await window.origin.offset(by: parameter.point))
            }
        }
    }

    /// A status menu item: shows a view file template for the front plug-in, listing its parameters, for the user to arrange and save in the Plug-In Views folder.
    @MainActor
    static var displayViewTemplate: Command {
        Command("plugin.displayPluginViewTemplate", "Display Plugin View Template", scope: .windows([.plugIn]), triggers: [.statusMenu]) { _ in
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
