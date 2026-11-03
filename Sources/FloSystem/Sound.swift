import AppKit

/// Feedback sounds, shipped in the app's `Contents/Resources` (copied from `Resources/Sounds` by `scripts/build-app.sh`). The KM version played system sounds such as `/System/Library/Sounds/Tink.aiff`; bundling them keeps Flo Tools independent of what macOS ships.
@MainActor
public enum Sound: String {
    /// An action finished, for example after a double press. Was Tink.
    case done = "Done"
    /// A long job is still working, for example during Unsolo All. Was Pop.
    case progress = "Progress"

    public func play() {
        guard let url = Bundle.main.url(forResource: rawValue, withExtension: "aiff"), let sound = NSSound(contentsOf: url, byReference: true) else {
            Log.warning(.app, "sound \(rawValue).aiff is missing from the app bundle")
            return
        }
        sound.play()
    }
}

/// Plays the progress sound at most once per `interval` during a long job, such as Unsolo All or waiting for Freeze, so the user hears that it is still working.
public struct ProgressTicker: Sendable {
    private let interval: Duration
    private var lastSound: ContinuousClock.Instant

    public init(every interval: Duration = .seconds(1), startingAt start: ContinuousClock.Instant = .now) {
        self.interval = interval
        self.lastSound = start
    }

    /// Plays the progress sound if more than `interval` passed since the start or the last sound.
    public mutating func tick() async {
        if isDue(at: .now) { await Sound.progress.play() }
    }

    /// Whether the sound is due at `now`; when it is, `now` becomes the last sound.
    mutating func isDue(at now: ContinuousClock.Instant) -> Bool {
        guard now - lastSound > interval else { return false }
        lastSound = now
        return true
    }
}
