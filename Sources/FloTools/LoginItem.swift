import FloEngine
import FloSystem
import ServiceManagement

/// Launch on Login: Flo Tools as the user's login item, through `SMAppService.mainApp`. The service's status is the setting, so a change in System Settings > Login Items shows in the preferences panel.
/// Like VOCR, it is turned on once, on the first launch from an Applications folder. A copy run from Downloads, a disk image or a build folder is not registered, because the login item would open that copy.
/// Main actor: the app and the preferences panel read and change it.
@MainActor
final class LoginItem {
    private let preferences: PreferencesStore
    private var service: SMAppService { .mainApp }

    init(preferences: PreferencesStore) {
        self.preferences = preferences
    }

    var isEnabled: Bool { service.status == .enabled }

    /// Shown in the diagnostic log header.
    var statusDescription: String {
        switch service.status {
        case .enabled: "on"
        case .notRegistered: "off"
        // What macOS reports before the app was ever registered.
        case .notFound: "off (never registered)"
        case .requiresApproval: "waiting for approval in System Settings"
        @unknown default: "unknown (\(service.status.rawValue))"
        }
    }

    func enableOnFirstLaunch() {
        guard !preferences.launchOnLoginOffered, Self.isInApplicationsFolder else { return }
        preferences.launchOnLoginOffered = true
        Log.info(.app, "first launch from Applications, turning on Launch on Login")
        register(true)
    }

    private static var isInApplicationsFolder: Bool {
        let folder = Bundle.main.bundleURL.deletingLastPathComponent().standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").standardizedFileURL.path
        return folder == "/Applications" || folder == home
    }

    /// The user's choice in the preferences panel.
    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        register(enabled)
        // macOS can ask the user to allow the login item in System Settings before it runs.
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
            Task { await VoiceOver.sayOrLog("Allow Flo Tools in Login Items in System Settings.") }
        }
    }

    private func register(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            Log.info(.app, "Launch on Login \(statusDescription)")
        } catch {
            Log.error(.app, "could not turn Launch on Login \(enabled ? "on" : "off"): \(error)")
            Task { await VoiceOver.sayOrLog("Could not change Launch on Login.") }
        }
    }
}
