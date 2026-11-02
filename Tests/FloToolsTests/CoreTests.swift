import Foundation
import Testing
@testable import FloMacros
@testable import FloToolsCore

@Suite struct GroupTests {
    @Test func groupConditions() throws {
        let inspector = try #require(FloMacros.groups.first { $0.id == .inspector })
        #expect(inspector.applies(to: FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Mix: I Trust")))
        #expect(inspector.applies(to: FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Edit: I Trust")))
        #expect(!inspector.applies(to: FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Plug-in: EQ3")))
        #expect(!inspector.applies(to: FrontContext(bundleID: "com.apple.finder", windowTitle: "Mix: I Trust")))

        let fadeIn = try #require(FloMacros.groups.first { $0.id == .fadeIn })
        #expect(fadeIn.applies(to: FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Fade In")))
        #expect(!fadeIn.applies(to: FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Fade In Out")))

        let global = try #require(FloMacros.groups.first { $0.id == .global })
        #expect(global.applies(to: FrontContext(bundleID: "com.apple.finder")))
    }
}

@MainActor @Suite struct EngineTests {
    static let proTools = "com.avid.ProTools"
    let mix = FrontContext(bundleID: proTools, windowTitle: "Mix: Session")
    let plugin = FrontContext(bundleID: proTools, windowTitle: "Plug-in: EQ3 7-Band")

    @Test func allMacrosInstall() {
        let engine = FloMacros.makeEngine()
        #expect(engine.macros.count == FloMacros.all.count)
        #expect(engine.macro("inspector.speakOpenSendB")?.hotKeys.map(\.combo.description) == ["Ctrl+2"])
    }

    @Test func onlyMacrosInMatchingContextAreActive() {
        let engine = MacroEngine(groups: FloMacros.groups)
        let ctrl2 = KeyCombo(keyCode: 19, modifiers: KeyCombo.control)
        #expect(engine.activeCombos(in: mix).isEmpty)

        engine.install(Macro("test.sendB", "Send B", group: .inspector, triggers: [.key("Ctrl+2")]) {})
        #expect(engine.activeCombos(in: mix) == [ctrl2])
        #expect(engine.candidates(for: ctrl2, phase: .pressed, in: mix).map(\.id) == ["test.sendB"])
        #expect(engine.candidates(for: ctrl2, phase: .released, in: mix).isEmpty)
        #expect(engine.activeCombos(in: plugin).isEmpty)

        engine.setGroup(.inspector, enabled: false)
        #expect(engine.activeCombos(in: mix).isEmpty)
        engine.setGroup(.inspector, enabled: true)
        engine.setMacro("test.sendB", enabled: false)
        #expect(engine.activeCombos(in: mix).isEmpty)
    }

    @Test func windowSpecificGroupWinsOverAppGroup() {
        // In KM, Cmd+1 is "Tab 1" in Selected Tab, "Assign Insert A" in Inspector and "Load Plugin Parameters for View 1" in Plugin.
        let engine = MacroEngine(groups: FloMacros.groups)
        for group in [MacroGroupID.floTools, .inspector, .plugin] {
            engine.install(Macro(MacroID("test.\(group)"), "Cmd+1", group: group, triggers: [.key("Cmd+1")]) {})
        }
        let cmd1 = KeyCombo(keyCode: 18, modifiers: KeyCombo.command)
        #expect(engine.candidates(for: cmd1, phase: .pressed, in: plugin).first?.group == .plugin)
        #expect(engine.candidates(for: cmd1, phase: .pressed, in: mix).first?.group == .inspector)
    }
}

@MainActor @Suite struct DoublePressTests {
    @Test func singlePressRunsAfterTimeout() async throws {
        let detector = DoublePress(timeout: .milliseconds(50))
        var log: [String] = []
        detector.press("a", single: { log.append("single") }, double: { log.append("double") })
        #expect(log.isEmpty)
        try await Task.sleep(for: .milliseconds(200))
        #expect(log == ["single"])
    }

    @Test func secondPressInTimeRunsDoubleOnly() async throws {
        let detector = DoublePress(timeout: .milliseconds(100))
        var log: [String] = []
        detector.press("a", single: { log.append("single") }, double: { log.append("double") })
        detector.press("a", single: { log.append("single") }, double: { log.append("double") })
        try await Task.sleep(for: .milliseconds(250))
        #expect(log == ["double"])
    }

    @Test func differentCommandsDoNotCombine() async throws {
        let detector = DoublePress(timeout: .milliseconds(50))
        var log: [String] = []
        detector.press("a", single: { log.append("a") }, double: { log.append("aa") })
        detector.press("b", single: { log.append("b") }, double: { log.append("bb") })
        try await Task.sleep(for: .milliseconds(200))
        #expect(log.sorted() == ["a", "b"])
    }
}

@Suite struct PreferencesTests {
    @Test func readsKeyboardMaestroFormat() {
        let json = #"{"temporary inspector":true,"starts with Flo Tools inspector":true,"timeout":"300"}"#
        let prefs = Preferences.decode(Data(json.utf8))
        #expect(prefs.temporaryInspector)
        #expect(prefs.startsWithInspector)
        #expect(prefs.timeout == 300)
    }

    @Test func roundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        var prefs = Preferences()
        prefs.timeout = 400
        prefs.temporaryInspector = true
        try prefs.save(to: url)
        #expect(Preferences.load(from: url) == prefs)
    }
}

@Suite struct MacroTextTests {
    @Test func keyComboParsesItsDescription() {
        for code in KeyCombo.keyNames.keys {
            for modifiers: UInt32 in [0, KeyCombo.command, KeyCombo.control | KeyCombo.option | KeyCombo.shift] {
                let combo = KeyCombo(keyCode: code, modifiers: modifiers)
                #expect(KeyCombo(combo.description) == combo, "\(combo)")
            }
        }
        #expect(KeyCombo("Ctrl+Nope") == nil)
    }

    @Test func keyComboNames() {
        #expect(KeyCombo(keyCode: 1, modifiers: KeyCombo.option | KeyCombo.shift).description == "Opt+Shift+S")
        #expect(KeyCombo(keyCode: 78, modifiers: KeyCombo.control | KeyCombo.option).description == "Ctrl+Opt+Keypad -")
    }

    @Test func sendMessageMatchesJXA() {
        #expect(Inspector.sendMessage(selectorName: "Send selector B", selectorValue: "unassigned", assignmentValue: "unassigned") == " B. : unassigned")
        #expect(Inspector.sendMessage(selectorName: "Send selector B", selectorValue: "Bus 1", assignmentValue: "Send Assignment Reverb") == " B. Bus 1: Reverb")
    }

    @Test func soloFilter() {
        #expect(TrackStatus.isSoloed(trackName: "Kick - Audio Track ", soloValue: "on"))
        #expect(!TrackStatus.isSoloed(trackName: "Kick - Audio Track ", soloValue: ""))
        #expect(!TrackStatus.isSoloed(trackName: "Kick - Audio Track ", soloValue: "on, solo safe"))
        #expect(!TrackStatus.isSoloed(trackName: "Kick - Audio Track ", soloValue: "Inactive"))
        #expect(!TrackStatus.isSoloed(trackName: "Master 1 - Master Track ", soloValue: "on"))
    }

    @Test func soloedMessageMatchesJXA() {
        #expect(TrackStatus.soloedMessage(names: []) == "No tracks are soloed.")
        #expect(TrackStatus.soloedMessage(names: ["Kick - Audio Track ", "Snare - Audio Track "]) == "2 Soloed: Kick - Audio. Snare - Audio. ")
    }
}
