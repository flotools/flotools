import AppKit
import FloEngine
import FloSystem
import Sparkle

/// Updates through Sparkle: the feed and its signing key are `SUFeedURL` and `SUPublicEDKey` in `Info.plist`, and the menu bar's Updates submenu holds the settings.
/// Sparkle keeps its own settings (check and download automatically) in the app's UserDefaults. Flo Tools adds two: whether a downloaded update is installed right away rather than when Flo Tools quits, and whether beta releases (appcast items in the `beta` channel) are offered.
/// Main actor: Sparkle's controller and delegates run there. Sparkle's user driver delegate protocol is not marked for the main actor, though Sparkle calls it there, so that conformance is `@preconcurrency`, which checks the actor at run time.
@MainActor
final class Updater: NSObject, SPUUpdaterDelegate, @preconcurrency SPUStandardUserDriverDelegate {
    private let preferences: PreferencesStore
    /// Created on `start`, because the delegates are `self`.
    private lazy var controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: self)
    private var updater: SPUUpdater { controller.updater }

    init(preferences: PreferencesStore) {
        self.preferences = preferences
    }

    /// Only a built app has the feed in its Info.plist; `swift run` starts nothing, so Sparkle shows no error about a missing feed.
    func start() {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            Log.info(.updates, "not an app bundle, updates are off")
            return
        }
        do {
            try updater.start()
            Log.info(.updates, "started: check automatically \(updater.automaticallyChecksForUpdates), download automatically \(updater.automaticallyDownloadsUpdates), install automatically \(preferences.installsUpdatesAutomatically), include beta \(preferences.includesBetaUpdates)")
        } catch {
            Log.error(.updates, "could not start the updater: \(error)")
        }
    }

    // MARK: Menu

    /// The Updates submenu: the version as a dimmed label, Check for Updates, and the four settings. A setting that depends on one that is off is dimmed.
    func menuItems() -> [NSMenuItem] {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let label = NSMenuItem(title: "Version \(version)", action: nil, keyEquivalent: "")
        label.isEnabled = false

        let check = item("Check for Updates…", #selector(checkForUpdates), enabled: updater.canCheckForUpdates)
        let checks = item("Automatically Check for Updates", #selector(toggleAutomaticChecks), on: updater.automaticallyChecksForUpdates)
        let downloads = item("Automatically Download Updates", #selector(toggleAutomaticDownloads), on: updater.automaticallyDownloadsUpdates, enabled: updater.automaticallyChecksForUpdates && updater.allowsAutomaticUpdates)
        let installs = item("Automatically Install Updates", #selector(toggleAutomaticInstall), on: preferences.installsUpdatesAutomatically, enabled: downloads.isEnabled && updater.automaticallyDownloadsUpdates)
        let beta = item("Include Beta Updates", #selector(toggleBeta), on: preferences.includesBetaUpdates)
        return [label, check, .separator(), checks, downloads, installs, beta]
    }

    private func item(_ title: String, _ action: Selector, on: Bool? = nil, enabled: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        if let on { item.state = on ? .on : .off }
        item.isEnabled = enabled
        return item
    }

    @objc private func checkForUpdates() {
        Log.info(.updates, "check for updates chosen")
        updater.checkForUpdates()
    }

    @objc private func toggleAutomaticChecks() {
        updater.automaticallyChecksForUpdates.toggle()
        Log.info(.updates, "check automatically \(updater.automaticallyChecksForUpdates)")
    }

    @objc private func toggleAutomaticDownloads() {
        updater.automaticallyDownloadsUpdates.toggle()
        Log.info(.updates, "download automatically \(updater.automaticallyDownloadsUpdates)")
    }

    @objc private func toggleAutomaticInstall() {
        preferences.installsUpdatesAutomatically.toggle()
    }

    /// The next check uses the new channels; a check already scheduled is not moved.
    @objc private func toggleBeta() {
        preferences.includesBetaUpdates.toggle()
    }

    // MARK: SPUUpdaterDelegate

    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        preferences.includesBetaUpdates ? ["beta"] : []
    }

    /// Sparkle calls this when an update was downloaded in the background. Returning false leaves it to install when Flo Tools quits; returning true and calling the handler installs it now and relaunches Flo Tools.
    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem, immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        let version = item.displayVersionString
        guard preferences.installsUpdatesAutomatically else {
            Log.info(.updates, "downloaded \(version), installs when Flo Tools quits")
            return false
        }
        Log.info(.updates, "downloaded \(version), installing now")
        Task {
            await VoiceOver.sayOrLog("Installing Flo Tools \(version). Flo Tools will restart.")
            immediateInstallHandler()
        }
        return true
    }

    /// Sparkle also ends a check that found nothing this way.
    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        let error = error as NSError
        if error.domain == SUSparkleErrorDomain, error.code == Int(SUError.noUpdateError.rawValue) {
            Log.info(.updates, "no update: \(error.localizedRecoverySuggestion ?? error.localizedDescription)")
        } else {
            Log.warning(.updates, "update stopped: \(error)")
        }
    }

    // MARK: SPUStandardUserDriverDelegate

    /// Flo Tools has no Dock icon, so Sparkle puts a scheduled update's window behind the front app, where a VoiceOver user would not find it. VoiceOver says that it is there instead.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        guard !state.userInitiated else { return }
        let version = update.displayVersionString
        Log.info(.updates, "found \(version)")
        Task { await VoiceOver.sayOrLog("Flo Tools \(version) is available. Choose Check for Updates in the Flo Tools menu to install it.") }
    }
}
