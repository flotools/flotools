import FloSystem
import Foundation

/// The user's preferences, the three settings of the KM preferences dialog.
public struct Preferences: Equatable, Sendable {
    /// Whether holding backtick turns the Inspector on while held (Toggle Temporary Inspector).
    public var temporaryInspector = false
    /// Whether the Inspector is on when Flo Tools or Pro Tools starts.
    public var startsWithInspector = false
    /// Double-press timeout in milliseconds, one of `timeoutChoices`.
    public var timeout = 200

    /// The values the KM preferences dialog offered.
    public static let timeoutChoices = [200, 300, 400, 500]

    public init() {}
}

/// Preferences kept in UserDefaults, and the ones now in effect. The app creates one and passes it to whoever needs the values. Main actor: the menu, the preferences panel and command setup read and change it.
@MainActor
public final class PreferencesStore {
    /// Not `.standard` in tests, so they never touch the user's settings.
    private let defaults: UserDefaults
    public private(set) var current: Preferences

    enum Key {
        static let temporaryInspector = "temporaryInspector"
        static let startsWithInspector = "startsWithInspector"
        static let timeout = "doublePressTimeout"
        static let floToolsEnabled = "floToolsEnabled"
        static let plugInViewsInstalled = "plugInViewsInstalled"
        static let installsUpdatesAutomatically = "installsUpdatesAutomatically"
        static let includesBetaUpdates = "includesBetaUpdates"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        current = Self.read(defaults)
        Log.info(.preferences, "loaded \(current)")
    }

    public func save(_ preferences: Preferences) {
        defaults.set(preferences.temporaryInspector, forKey: Key.temporaryInspector)
        defaults.set(preferences.startsWithInspector, forKey: Key.startsWithInspector)
        defaults.set(preferences.timeout, forKey: Key.timeout)
        current = preferences
        Log.info(.preferences, "saved \(preferences)")
    }

    /// The "Flo Tools Enabled" switch of the menu bar menu, remembered across launches as KM remembered a disabled group. Kept apart from `Preferences` because the preferences panel does not edit it. On when never set.
    public var floToolsEnabled: Bool {
        get { defaults.object(forKey: Key.floToolsEnabled) as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: Key.floToolsEnabled)
            Log.info(.preferences, "saved Flo Tools \(newValue ? "enabled" : "disabled")")
        }
    }

    /// Whether the shipped plug-in views were copied into the user's folder, which happens once, on the first launch. After that a view file the user deletes stays deleted. Off when never set.
    public var plugInViewsInstalled: Bool {
        get { defaults.bool(forKey: Key.plugInViewsInstalled) }
        set { defaults.set(newValue, forKey: Key.plugInViewsInstalled) }
    }

    /// Whether an update that Sparkle downloaded in the background is installed right away, relaunching Flo Tools, instead of when Flo Tools quits. Sparkle keeps its own check and download settings. Off when never set.
    public var installsUpdatesAutomatically: Bool {
        get { defaults.bool(forKey: Key.installsUpdatesAutomatically) }
        set {
            defaults.set(newValue, forKey: Key.installsUpdatesAutomatically)
            Log.info(.preferences, "saved install updates automatically \(newValue)")
        }
    }

    /// Whether update checks also offer beta releases, the appcast items in the `beta` channel. Off when never set.
    public var includesBetaUpdates: Bool {
        get { defaults.bool(forKey: Key.includesBetaUpdates) }
        set {
            defaults.set(newValue, forKey: Key.includesBetaUpdates)
            Log.info(.preferences, "saved include beta updates \(newValue)")
        }
    }

    /// Missing values are defaults. A timeout outside `timeoutChoices`, which only `defaults write` can set, is logged and replaced by the default, so double presses stay usable.
    private static func read(_ defaults: UserDefaults) -> Preferences {
        var preferences = Preferences()
        preferences.temporaryInspector = defaults.bool(forKey: Key.temporaryInspector)
        preferences.startsWithInspector = defaults.bool(forKey: Key.startsWithInspector)
        if defaults.object(forKey: Key.timeout) != nil {
            let timeout = defaults.integer(forKey: Key.timeout)
            if Preferences.timeoutChoices.contains(timeout) {
                preferences.timeout = timeout
            } else {
                Log.warning(.preferences, "timeout \(timeout) is not one of \(Preferences.timeoutChoices), using \(preferences.timeout)")
            }
        }
        return preferences
    }
}
