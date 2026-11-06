import Foundation
import FloEngine
import FloSystem

/// Launch on Login, as in VOCR: a launch agent in `~/Library/LaunchAgents` that runs Flo Tools when the user logs in. The agent file is the setting.
/// The agent names the executable of the copy that turned it on, not a fixed `/Applications` path, so it works wherever that copy is installed.
/// It is turned on once, on the first launch from an Applications folder. A copy run from Downloads, a disk image or a build folder is not registered, because the agent would run that copy.
/// Main actor: the app and the preferences panel read and change it.
@MainActor
final class LoginItem {
    static let label = "com.chikim.FloTools"

    private let preferences: PreferencesStore
    private let agentURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents/\(LoginItem.label).plist")

    init(preferences: PreferencesStore) {
        self.preferences = preferences
    }

    var isEnabled: Bool { FileManager.default.fileExists(atPath: agentURL.path) }

    /// Shown in the diagnostic log header: the copy the agent runs, which may not be this one.
    var statusDescription: String {
        guard isEnabled else { return "off" }
        guard let program = agentProgram else { return "on, agent file unreadable" }
        return "on, runs \(Log.redactingHome(program))"
    }

    private var agentProgram: String? {
        guard let data = try? Data(contentsOf: agentURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return plist["Program"] as? String
    }

    func enableOnFirstLaunch() {
        guard !preferences.launchOnLoginOffered, Self.isInApplicationsFolder else { return }
        preferences.launchOnLoginOffered = true
        Log.info(.app, "first launch from Applications, turning on Launch on Login")
        setEnabled(true)
    }

    private static var isInApplicationsFolder: Bool {
        let folder = Bundle.main.bundleURL.deletingLastPathComponent().standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").standardizedFileURL.path
        return folder == "/Applications" || folder == home
    }

    /// Turning it on writes the agent for this copy; turning it off removes the file.
    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        do {
            if enabled {
                try writeAgent()
            } else {
                try FileManager.default.removeItem(at: agentURL)
            }
            Log.info(.app, "Launch on Login \(statusDescription)")
        } catch {
            Log.error(.app, "could not turn Launch on Login \(enabled ? "on" : "off"): \(error)")
            Task { await VoiceOver.sayOrLog("Could not change Launch on Login.") }
        }
    }

    private func writeAgent() throws {
        guard let program = Bundle.main.executablePath else { throw CocoaError(.fileNoSuchFile) }
        let agent: [String: Any] = [
            "Label": Self.label,
            "Program": program,
            "RunAtLoad": true,
            // Only in a graphical login session, and not restarted when the user quits Flo Tools.
            "LimitLoadToSessionType": "Aqua",
            "KeepAlive": false,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: agent, format: .xml, options: 0)
        try FileManager.default.createDirectory(at: agentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: agentURL, options: .atomic)
    }
}
