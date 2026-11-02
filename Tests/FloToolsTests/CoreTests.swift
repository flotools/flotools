import Foundation
import Testing
@testable import FloMacros
@testable import FloToolsCore

@Suite struct CatalogTests {
    @Test func catalogMatchesExport() {
        #expect(Catalog.macros.count == 300)
        #expect(Set(Catalog.groups.map(\.name)).count == 12)
        #expect(Set(Catalog.macros.map(\.uid)).count == 300)
    }

    @Test func sendBHotkeyIsControl2() throws {
        let macro = try #require(Catalog.macros.first { $0.uid == "F9ED77CC-B335-4608-BDBE-C560B3AC30F9" })
        #expect(macro.group == "Flo Tools Inspector")
        #expect(macro.hotKeys.map(\.combo.description) == ["Ctrl+2"])
    }

    @Test func groupConditions() throws {
        let inspector = try #require(Catalog.groups.first { $0.name == "Flo Tools Inspector" })
        #expect(inspector.applies(to: FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Mix: I Trust")))
        #expect(inspector.applies(to: FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Edit: I Trust")))
        #expect(!inspector.applies(to: FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Plug-in: EQ3")))
        #expect(!inspector.applies(to: FrontContext(bundleID: "com.apple.finder", windowTitle: "Mix: I Trust")))

        let fadeIn = try #require(Catalog.groups.first { $0.name == "Flo Tools Fade In" })
        #expect(fadeIn.applies(to: FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Fade In")))
        #expect(!fadeIn.applies(to: FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Fade In Out")))

        let mouse = try #require(Catalog.groups.first { $0.name == "Flo Mouse" })
        #expect(!mouse.enabledByDefault)
        #expect(mouse.applies(to: FrontContext(bundleID: "com.apple.finder")))
    }
}

@MainActor @Suite struct EngineTests {
    @Test func onlyPortedMacrosInMatchingContextAreActive() {
        let engine = MacroEngine()
        let ctrl2 = KeyCombo(keyCode: 19, modifiers: KeyCombo.control)
        let mix = FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Mix: Session")
        #expect(engine.activeCombos(in: mix).isEmpty)

        engine.register("F9ED77CC-B335-4608-BDBE-C560B3AC30F9") {}
        #expect(engine.activeCombos(in: mix) == [ctrl2])
        #expect(engine.candidates(for: ctrl2, onRelease: false, in: mix).map(\.name) == ["Speak/Open Send B"])
        #expect(engine.activeCombos(in: FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Plug-in: EQ3")).isEmpty)

        engine.setGroup("Flo Tools Inspector", enabled: false)
        #expect(engine.activeCombos(in: mix).isEmpty)
    }

    @Test func windowSpecificGroupWinsOverAppGroup() {
        // Cmd+1 is "Tab 1" in Selected Tab, "Assign Insert A" in Inspector and "Load Plugin Parameters for View 1" in Plugin.
        let engine = MacroEngine()
        let cmd1 = KeyCombo(keyCode: 18, modifiers: KeyCombo.command)
        for macro in engine.macros where macro.hotKeys.contains(where: { $0.combo == cmd1 }) {
            engine.register(macro.uid) {}
        }
        let plugin = FrontContext(bundleID: "com.avid.ProTools", windowTitle: "Plug-in: EQ3 7-Band")
        #expect(engine.candidates(for: cmd1, onRelease: false, in: plugin).first?.group == "Flo Tools Plugin")
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
