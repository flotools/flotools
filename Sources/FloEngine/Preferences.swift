import FloSystem
import Foundation

/// The user's Inspector and double-press preferences.
public struct Preferences: Equatable, Sendable {
    /// Whether holding backtick turns the Inspector on while held (Toggle Temporary Inspector).
    public var temporaryInspector = false
    /// Whether each press of an Inspector key turns the Inspector on or off by itself, by checking whether the VoiceOver cursor is on a track name.
    public var autoInspector = false
    /// Whether the Inspector is on when Flo Tools or Pro Tools starts.
    public var startsWithInspector = false
    /// In milliseconds, one of `timeoutChoices`: the double-press timeout, or with `holdForDoublePress` the hold time.
    public var timeout = 200
    /// Whether holding a key for `timeout` runs its double action instead of a second press. Double presses then do not work, and a tap acts as soon as the key is let go. Off by default, because someone who presses keys slowly could switch solo, mute or record arm by accident.
    public var holdForDoublePress = false

    /// A shorter time makes a single press act sooner, or a hold shorter, but leaves less time for the second press of a double, or for letting go of a tap.
    public static let timeoutChoices = [100, 200, 300, 400, 500]

    /// What these preferences make the double action of a key.
    public var doubleActionTrigger: DoubleActionTrigger {
        holdForDoublePress ? .hold(for: .milliseconds(timeout)) : .secondPress(within: .milliseconds(timeout))
    }

    public init() {}
}

/// The one wording of the preferences for the log, used by the diagnostic header and when preferences are loaded or saved.
extension Preferences: CustomStringConvertible {
    public var description: String {
        "temporary inspector \(temporaryInspector), auto inspector \(autoInspector), starts with Flo Tools inspector \(startsWithInspector), hold for double press \(holdForDoublePress), \(holdForDoublePress ? "hold time" : "timeout") \(timeout) ms"
    }
}

/// Preferences kept in UserDefaults, and the ones now in effect. The app creates one and passes it to whoever needs the values. Main actor: the menu, the preferences panel and command setup read and change it.
@MainActor
public final class PreferencesStore {
    /// Not `.standard` in tests, so they never touch the user's settings.
    private let defaults: UserDefaults
    public private(set) var current: Preferences

    enum Key {
        static let temporaryInspector = "temporaryInspector"
        static let autoInspector = "autoInspector"
        static let startsWithInspector = "startsWithInspector"
        /// Also the hold time with `holdForDoublePress`; the key keeps its older name so the saved value stays.
        static let timeout = "doublePressTimeout"
        static let holdForDoublePress = "holdForDoublePress"
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
        defaults.set(preferences.temporaryInspector, forKey: Key.temporaryInspector)
        defaults.set(preferences.autoInspector, forKey: Key.autoInspector)
        defaults.set(preferences.startsWithInspector, forKey: Key.startsWithInspector)
        defaults.set(preferences.timeout, forKey: Key.timeout)
        defaults.set(preferences.holdForDoublePress, forKey: Key.holdForDoublePress)
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

    /// Missing values are defaults. A timeout outside its choices, which only `defaults write` can set, is logged and replaced by the default, so double presses stay usable.
    private static func read(_ defaults: UserDefaults) -> Preferences {
        var preferences = Preferences()
        preferences.temporaryInspector = defaults.bool(forKey: Key.temporaryInspector)
        preferences.autoInspector = defaults.bool(forKey: Key.autoInspector)
        preferences.startsWithInspector = defaults.bool(forKey: Key.startsWithInspector)
        preferences.holdForDoublePress = defaults.bool(forKey: Key.holdForDoublePress)
        preferences.timeout = choice(Key.timeout, in: Preferences.timeoutChoices, default: preferences.timeout, defaults)
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
