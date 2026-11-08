import FloSystem
import Foundation

/// The preferences that change how keys work.
public struct Preferences: Equatable, Sendable {
    /// In milliseconds, one of `holdTimeChoices`: how long a key with a tap and a hold action must stay down to count as held.
    public var holdTime = 200

    /// A shorter time makes a hold shorter, but leaves less time to let go of a tap.
    public static let holdTimeChoices = [100, 200, 300, 400, 500]

    public init() {}
}

/// The one wording of the preferences for the log, used by the diagnostic header and when preferences are loaded or saved.
extension Preferences: CustomStringConvertible {
    public var description: String {
        "hold time \(holdTime) ms"
    }
}

/// Preferences kept in UserDefaults, and the ones now in effect. The app creates one and passes it to whoever needs the values. Main actor: the menu, the preferences panel and command setup read and change it.
@MainActor
public final class PreferencesStore {
    /// Not `.standard` in tests, so they never touch the user's settings.
    private let defaults: UserDefaults
    public private(set) var current: Preferences

    enum Key {
        /// The key keeps its name from when the time was a double-press timeout, so the saved value stays.
        static let holdTime = "doublePressTimeout"
        static let floToolsEnabled = "floToolsEnabled"
        static let plugInViewsInstalled = "plugInViewsInstalled"
        static let installsUpdatesAutomatically = "installsUpdatesAutomatically"
        static let includesBetaUpdates = "includesBetaUpdates"
        static let launchOnLoginOffered = "launchOnLoginOffered"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        current = Self.read(defaults)
        Log.info(.preferences, "loaded \(current)")
    }

    public func save(_ preferences: Preferences) {
        defaults.set(preferences.holdTime, forKey: Key.holdTime)
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

    /// Whether Launch on Login was turned on by the first launch from an Applications folder, which happens once. After that it stays as the user leaves it. Off when never set.
    public var launchOnLoginOffered: Bool {
        get { defaults.bool(forKey: Key.launchOnLoginOffered) }
        set { defaults.set(newValue, forKey: Key.launchOnLoginOffered) }
    }

    /// Missing values are defaults. A hold time outside its choices, which only `defaults write` can set, is logged and replaced by the default, so holds stay usable.
    private static func read(_ defaults: UserDefaults) -> Preferences {
        var preferences = Preferences()
        preferences.holdTime = choice(Key.holdTime, in: Preferences.holdTimeChoices, default: preferences.holdTime, defaults)
        return preferences
    }

    private static func choice(_ key: String, in choices: [Int], default value: Int, _ defaults: UserDefaults) -> Int {
        guard defaults.object(forKey: key) != nil else { return value }
        let stored = defaults.integer(forKey: key)
        guard choices.contains(stored) else {
            Log.warning(.preferences, "\(key) \(stored) is not one of \(choices), using \(value)")
            return value
        }
        return stored
    }
}
