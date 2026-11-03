import FloEngine
import FloProTools
import FloSystem

/// Flo Tools Selected Tab group: Cmd+1 to Cmd+9 pick a tab in tabbed windows such as Preferences and I/O Setup.
enum SelectedTab {
    @MainActor
    static var macros: [Macro] { (1...9).map(tab) }

    /// Presses tab `number` and speaks "<tab name> selected", as the JXA did.
    @MainActor
    static func tab(_ number: Int) -> Macro {
        Macro(MacroID("selectedTab.tab\(number)"), "Tab \(number)", group: .selectedTab, triggers: [.key("Cmd+\(number)")]) { _ in
            let name = try await ProToolsApp.running().selectTab(number)
            try await VoiceOver.say(name + " selected")
        }
    }
}
