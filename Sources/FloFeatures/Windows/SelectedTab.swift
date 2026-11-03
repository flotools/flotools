import FloEngine
import FloProTools
import FloSystem

/// Selected Tab: Cmd+1 to Cmd+9 pick a tab in tabbed windows such as Preferences and I/O Setup.
enum SelectedTab {
    @MainActor
    static var commands: [Command] { (1...9).map(tab) }

    /// Presses tab `number` and speaks "<tab name> selected", as the JXA did.
    @MainActor
    static func tab(_ number: Int) -> Command {
        Command(CommandID("selectedTab.tab\(number)"), "Tab \(number)", summary: "Selects tab \(number) of a tabbed window, such as Preferences or I/O Setup, and speaks its name.", scope: .windows([.tabbedSetup]), triggers: [.key("Cmd+\(number)")]) { _ in
            let name = try await ProToolsApp.running().selectTab(number)
            try await VoiceOver.say(name + " selected")
        }
    }
}
